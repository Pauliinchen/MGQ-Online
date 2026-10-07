#----------------------------------------------------------------
#  coop.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Added the helpers the party scripts shared copies of: a message's bytes and an event's name for the log, a random id and an option's registration in the Mod Config
#                            - Logged invites sent, received, accepted, declined, run out and turned away with the reason, whom the leader admitted, the leader and why, and the party messages dropped
#      Paulinchen  2026-10-06: Counted the player as a candidate for the party's leader only once the leader admitted them, so a player turned away as they join leaves the party
#                            - Added party_leader and party_leading?, which every party script asks
#                            - Added the party's choices to the action wheel's ring by order instead of to fixed sides
#      Paulinchen  2026-10-04: Handed the party chat's lines to ui_chat.rbx through the party's gate
#                            - Teleported to the leader through coop_gather.rbx
#                            - Renamed from mp_coop.rbx
#      Paulinchen  2026-10-03: Offered a party's member to teleport to its leader, on the wheel in place of the invite and on the leader's row of the World overview
#                            - Offered the party's choices and invites to the wheel, the World overview and the notification box through MGQ_MpActions
#                            - Sent messages, showed notices and read the world, the own id and the own seat through MGQ_MpOverworldSync
#                            - Logged through MGQ_MpLog
#                            - Counted only the players the party's leader admitted as its members, whom the leader's invite reached
#                            - Read the bound keys through MGQ_MpHotkeys, renamed from MGQ_MpKeys
#                            - Listed an event's pages, for the party's chests
#                            - Let a party invite to a player named from afar stand a minute instead of fifteen seconds
#                            - Declined a party invite, telling the inviter, whose invite stops naming the player
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
# messages. The party scripts after it (coop_events.rbx, coop_scene.rbx, coop_npcs.rbx,
# coop_story.rbx, battles_coop.rbx and battles_duel.rbx) register here for their fields, as does
# the party chat of ui_chat.rbx; this script takes those messages from
# overworld_sync.rbx, drops those of another party, and hands on the rest.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoop
  # Tiles another player may be away, on the same map, to be invited or to accept.
  NEAR_TILES = 2

  # Frames an invite stands, fifteen seconds at 60 frames per second.
  INVITE_FRAMES = 900

  # Frames an invite to a player named from afar stands, a minute: they first have to notice it in
  # the notification box (ui_notices.rbx) or the World overview.
  NAMED_INVITE_FRAMES = 3600

  # Players a party holds at most, one per place of the Frontline they share.
  MAX_PLAYERS = 4

  # Frames after a player joined in which others the invite reached may still join, three seconds,
  # since several may accept before any of them sees another join and the invite stop.
  LATE_FRAMES = 180

  # Color of the invite line above a ghost's name and above the player's own head.
  INVITE_COLOR = MGQ_MpActions::LINE_COLOR

  # What a player reads once a party's leader turned them away as they joined, after the leader's
  # name, by the reason the leader gives.
  TURNED_AWAY = { "full" => "'s party is full", "late" => "'s invite is over" }

  @routes = {}

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op"

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

  # Takes a message of the party, dropping one of another party, from a player the party's leader
  # did not admit, or from a player the game does not know yet.
  #
  # @param field [String] The field that marks it.
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  def self.take(field, peer, message)
    reason = drop_reason(peer, message)
    if reason
      sender = peer ? peer.state["id"] : nil
      log_once([:dropped, field, reason, sender], "dropped a #{field} message from #{MGQ_MpOverworldSync.who(peer)}: #{reason}")
      return
    end

    @routes[field].call(peer, message)
  end

  # Tells why the party drops a message.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent it.
  # @param message [Hash] The message's fields.
  # @return [String, nil] The reason, nil when the party takes it.
  def self.drop_reason(peer, message)
    return "the sender has not told their state yet" unless peer
    return "the player is in no party" unless Party.id
    return "it is party #{message['party']}'s, not #{Party.id}" unless message["party"] == Party.id
    return "the party's leader has not admitted the sender" unless Party.member?(peer.state)

    nil
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

  # Makes up an id of random digits and letters, such as a party's or a battle's.
  #
  # @param length [Integer] How many characters at most.
  # @return [String] The id.
  def self.random_id(length)
    rand(36**length).to_s(36)
  end

  # Adds an option with a few values to the Mod Config Remake's menu, or to the game's options
  # without it, before the menu's last entry.
  #
  # @param key [Symbol] The option's key in $game_system.conf.
  # @param name [String] The option's name in the menu.
  # @param help [String] What the menu says about it.
  # @param values [Hash{Integer => Array<String>}] Each value's name and help, the first the default.
  # @param fields [Hash] More of the entry's fields, such as :enable.
  def self.register_option(key, name, help, values, fields = {})
    config = NWConst::Config
    menu = config.const_defined?(:MOD_CONTENTS) ? config::MOD_CONTENTS : config::CONTENTS
    menu.insert(-2, { :key => key, :name => name, :sub => true, :help => "#{help}\r\n←/→ Toggle" }.merge(fields))
    config::DATA[key] = values.keys
    config::DATA_TEXT[key] = {}
    values.each { |value, (label, text)| config::DATA_TEXT[key][value] = { :name => label, :help => text } }
    config::DEFAULT[key] = values.keys.first
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

  # The fields the party adds to the state the player's game tells the others.
  #
  # @return [Hash] The fields.
  def self.state_fields
    { "party" => Party.id.to_s, "party_members" => Party.admitted.join(","),
      "invite" => Party.inviting? ? 1 : 0, "invite_to" => Party.targets.join(",") }
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

  # Counts the players of a party, the player included when it is theirs.
  #
  # @param id [String, nil] The party's id.
  # @return [Integer] The players, 0 for no party.
  def self.size_of(id)
    return 0 if id.to_s.empty?

    players_of(id).size + (id == Party.id ? 1 : 0)
  end

  # Lists the other players of a party: of the player's own only those its leader admitted, of
  # another party everyone who names it.
  #
  # @param id [String] The party's id.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players.
  def self.players_of(id)
    id == Party.id ? Party.members : MGQ_MpOverworldSync::Peers.all.select { |peer| peer.state["party"] == id }
  end

  # Finds the leader of a party: the player who made it, whose id starts the party's id, or the
  # player of it with the lowest id while they are gone, so every game finds the same one.
  #
  # The player counts only once the leader admitted them, as the leader's game counts them, or a
  # player turned away as they join would lead in their own game and ignore being turned away.
  #
  # @param id [String, nil] The party's id.
  # @return [MGQ_MpOverworldSync::Peers::Peer, Symbol, nil] The leader, :me for the player, nil for no party.
  def self.leader_of(id)
    return nil if id.to_s.empty?

    candidates = players_of(id).map { |peer| [peer.state["id"].to_s, peer] }
    candidates.unshift([MGQ_MpOverworldSync::Me.id, :me]) if id == Party.id && Party.admitted_me?
    return nil if candidates.empty?

    maker = candidates.find { |player_id, _| Party.maker?(player_id, id) }
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
    if in_world
      Party.count_down
    else
      log("no world open: left party #{Party.id}#{Party.inviting? ? ' and stopped inviting' : ''}") if Party.id || Party.inviting?
      Party.reset
    end
    watch
  end

  # Logs the party's leader and whom the leader admitted once either changed.
  def self.watch
    leader = party_leader
    key = leader == :me ? :me : (leader && leader.state["id"].to_s)
    if key != @logged_leader
      log(leader ? "the party's leader is #{MGQ_MpOverworldSync.who(leader)}: #{leader_reason(leader)}" : "the party has no leader: #{Party.id ? 'nobody else is in it' : 'the player is in no party'}") if leader || @logged_leader
      @logged_leader = key
    end

    admitted = Party.admitted.sort
    return if admitted == @logged_admitted

    log("admitted to party #{Party.id}: #{admitted.empty? ? 'nobody' : admitted.map { |id| name_of(id) }.join(', ')}") if Party.id
    @logged_admitted = admitted
  rescue => e
    log_once(:watch, "following the party for the log failed: #{e.class}: #{e.message}")
  end

  # Tells why a player leads the party, for the log.
  #
  # @param leader [MGQ_MpOverworldSync::Peers::Peer, Symbol] The leader, :me for the player.
  # @return [String] The reason.
  def self.leader_reason(leader)
    player_id = leader == :me ? MGQ_MpOverworldSync::Me.id : leader.state["id"].to_s
    Party.maker?(player_id) ? "they made the party" : "the maker is gone and theirs is the lowest id"
  end

  # Tells what the line above a ghost's name says: their invite, while they are outside the party.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The ghost's player.
  # @return [Array, nil] The text and its color, nil for none.
  def self.label_line(peer)
    peer.state["invite"] == "1" && !peer.member ? ["Invites to a party (#{MGQ_MpHotkeys.label(:wheel)})", INVITE_COLOR] : nil
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

      Party.near?(state) || (anywhere && state[named].to_s.split(",").include?(MGQ_MpOverworldSync::Me.id))
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

  # The player's party: the others who share its id and whom its leader admitted. Every game says
  # its party's id and whether it invites in the state it sends anyway, so joining needs no message
  # of its own: a player who accepts takes the inviter's id, and the inviter sees them join by it.
  #
  # Anyone can read a party's id in its members' states, so naming it is not enough: the leader
  # admits only a player the invite reached, and tells whom it admitted.
  module Party
    @id = nil
    @invite = Invite.new
    @admitted = []
    @turned_away = {}
    @late_frames = 0
    @late_targets = []
    @joining = false
    @invites_seen = {}

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

    # The ids of the players the party's leader admitted, which the leader keeps and every member
    # takes from the leader.
    #
    # @return [Array<String>] The ids, none outside a party.
    def self.admitted
      @id ? @admitted : []
    end

    # Reports whether a player made a party: their id starts the party's id.
    #
    # @param player_id [String] The player's id.
    # @param id [String] The party's id, the player's own party's by default.
    # @return [Boolean] Whether they did.
    def self.maker?(player_id, id = @id)
      !player_id.empty? && player_id[0, 8] == id[0, 8]
    end

    # Reports whether the player belongs to their party as its leader counts it: they made it, or
    # the leader admitted them since they joined.
    #
    # @return [Boolean] Whether they do.
    def self.admitted_me?
      !@id.nil? && !@joining
    end

    # Reports whether another player is in the player's party: one who names it, and who made it or
    # was admitted by its leader.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether they are.
    def self.member?(state)
      return false unless !@id.nil? && state["party"] == @id

      player_id = state["id"].to_s
      maker?(player_id) || @admitted.include?(player_id)
    end

    # Lists the other players in the party.
    #
    # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The members.
    def self.members
      MGQ_MpOverworldSync::Peers.all.select { |peer| member?(peer.state) }
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
      forget
      @invite.stop
    end

    # Forgets the party and whom its leader admitted.
    def self.forget
      @id = nil
      @admitted = []
      @turned_away = {}
      @late_frames = 0
      @late_targets = []
      @joining = false
    end

    # Lets an invite run out, and forgets a party nobody joined. Called every frame.
    def self.count_down
      if @late_frames > 0
        @late_frames -= 1
        MGQ_MpCoop.log("the moment for others to join late is over") if @late_frames == 0
      end
      return unless @invite.count_down

      nobody = members.empty?
      MGQ_MpCoop.log("the party invite ran out#{nobody ? ', nobody joined: forgot party ' + @id.to_s : ''}")
      forget if nobody
    end

    # Stops the invite once a player joined, leaving LATE_FRAMES to the others it reached.
    def self.close_invite
      return unless inviting?

      @late_targets = targets.dup
      @late_frames = LATE_FRAMES
      @invite.stop
      MGQ_MpCoop.log("closed the invite as a player joined; the others it reached may join for #{LATE_FRAMES / 60} s")
    end

    # Reports whether the invite reaches another player, or did as it stopped for a player who
    # joined a moment ago.
    #
    # @param state [Hash] What the other player last told.
    # @return [Boolean] Whether it does.
    def self.invite_reached?(state)
      @invite.covers?(state) || (@late_frames > 0 && (near?(state) || @late_targets.include?(state["id"].to_s)))
    end

    # Invites the players nearby, and a player anywhere in the world when named, making a party of
    # one for them to join.
    #
    # @param target_id [String, nil] The id of a player the invite reaches wherever they are.
    def self.invite(target_id = nil)
      standing = inviting?
      @invite.invite(target_id)
      @id ||= "#{MGQ_Multiplayer::Link.player_id[0, 8]}#{MGQ_MpCoop.random_id(6)}"
      named = target_id ? " and #{MGQ_MpCoop.name_of(target_id)} from afar" : ""
      MGQ_MpCoop.log("#{standing ? 'extended the invite' : 'inviting'} to party #{@id}: the players nearby#{named}, for #{(target_id ? NAMED_INVITE_FRAMES : INVITE_FRAMES) / 60} s")
    end

    # Stops inviting, forgetting a party nobody joined.
    def self.stop_inviting
      @invite.stop
      nobody = members.empty?
      MGQ_MpCoop.log("stopped inviting#{nobody ? ', nobody joined: forgot party ' + @id.to_s : ''}")
      forget if nobody
    end

    # Joins the party of a player who invites.
    #
    # @param inviter [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.join(inviter)
      party = inviter.state["party"]
      if full?(party)
        MGQ_MpCoop.log("did not join #{MGQ_MpOverworldSync.who(inviter)}: party #{party} is full (#{MGQ_MpCoop.size_of(party)}/#{MAX_PLAYERS})")
        return MGQ_MpOverworldSync.notice("#{inviter.state['name']}'s party is full.")
      end

      left = @id && !members.empty?
      old = @id
      forget
      @id = party
      @admitted = told_by(inviter)
      @joining = !@admitted.include?(MGQ_MpOverworldSync::Me.id)
      @invite.stop
      MGQ_MpCoop.log("accepted #{MGQ_MpOverworldSync.who(inviter)}'s invite to party #{@id}#{left ? ", leaving party #{old}" : ''}; " +
                     (@joining ? "waiting for the leader to admit the player" : "the leader admitted the player already"))
      MGQ_MpOverworldSync.notice("#{left ? 'You left your party and joined' : 'You joined'} #{inviter.state['name']}'s party.")
      MGQ_MpOverworldSync::Peers.all.each { |peer| peer.member = member?(peer.state) }
    end

    # Declines the invite of a player, telling them.
    #
    # @param inviter [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.decline(inviter)
      sent = MGQ_MpOverworldSync.tell(inviter.seat, "party_decline" => 1)
      MGQ_MpCoop.log("declined #{MGQ_MpOverworldSync.who(inviter)}'s invite to party #{inviter.state['party']}#{sent ? '' : ', but telling them failed'}")
    end

    # Notes that a player the invite reaches declined it: the invite stops naming them.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.declined_by(peer)
      unless @invite.covers?(peer.state)
        return MGQ_MpCoop.log("ignored #{MGQ_MpOverworldSync.who(peer)} declining: the player's invite does not reach them")
      end

      @invite.drop(peer.state["id"])
      MGQ_MpCoop.log("#{MGQ_MpOverworldSync.who(peer)} declined the party invite; it stops naming them")
      MGQ_MpOverworldSync.notice("#{peer.state['name']} declined your party invite.")
    end

    # Leaves the party.
    def self.leave
      MGQ_MpCoop.log("left party #{@id} with #{members.size} other member(s)")
      reset
      MGQ_MpOverworldSync.notice("You left the party.")
      MGQ_MpOverworldSync::Peers.all.each { |peer| peer.member = false }
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
      unless leader == :me && member?(peer.state)
        return MGQ_MpCoop.log("did not remove #{MGQ_MpOverworldSync.who(peer)}: #{leader == :me ? 'not a member' : 'only the leader removes'}")
      end

      MGQ_MpCoop.log("removed #{MGQ_MpOverworldSync.who(peer)} from party #{@id}")
      MGQ_MpCoop.tell(peer.seat, "kick", 1)
      player_id = peer.state["id"].to_s
      @admitted.delete(player_id)
      # Their state names the party until the message arrives, which must not turn them away again.
      @turned_away[player_id] = true
      peer.member = false
      MGQ_MpOverworldSync.notice("You removed #{peer.state['name']} from the party.")
    end

    # Leaves the party once its leader removed the player, or turned them away as they joined.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] Who removed them, which counts only from the leader.
    # @param reason [String, nil] A key of TURNED_AWAY when the player was turned away as they joined.
    def self.removed_by(peer, reason = nil)
      unless leader.equal?(peer)
        return MGQ_MpCoop.log("ignored being removed by #{MGQ_MpOverworldSync.who(peer)}: the party's leader is #{leader ? MGQ_MpOverworldSync.who(leader) : 'nobody'}")
      end

      MGQ_MpCoop.log(TURNED_AWAY.key?(reason) ? "#{MGQ_MpOverworldSync.who(peer)} turned the player away from party #{@id}: #{reason}" : "#{MGQ_MpOverworldSync.who(peer)} removed the player from party #{@id}")
      reset
      MGQ_MpOverworldSync.notice("#{peer.state['name']}#{TURNED_AWAY.fetch(reason, ' removed you from the party')}.")
      MGQ_MpOverworldSync::Peers.all.each { |other| other.member = false }
    end

    # Follows what another player just told: takes the leader's word on whom it admitted, admits
    # the player as the leader, and notices them coming into or going out of the party.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with what they just told.
    def self.observe(peer)
      adopt(peer)
      admit(peer)
      update(peer)
      note_invite(peer)
    end

    # Logs another player's invite once it starts or stops reaching the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with what they just told.
    def self.note_invite(peer)
      player_id = peer.state["id"].to_s
      reaches = invited_by?(peer)
      return if reaches == (@invites_seen[player_id] ? true : false)

      @invites_seen[player_id] = reaches
      party = peer.state["party"]
      MGQ_MpCoop.log(reaches ? "#{MGQ_MpOverworldSync.who(peer)} invites the player to party #{party} (#{near?(peer.state) ? 'standing near' : 'named from afar'}, #{MGQ_MpCoop.size_of(party)}/#{MAX_PLAYERS})" :
                               "#{MGQ_MpOverworldSync.who(peer)}'s invite no longer reaches the player")
    rescue => e
      MGQ_MpCoop.log_once(:note_invite, "noting an invite failed: #{e.class}: #{e.message}")
    end

    # Reads whom a player says the party's leader admitted, the player included, since a leader
    # who did not make the party is a member only by that list.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [Array<String>] The ids.
    def self.told_by(peer)
      peer.state["party_members"].to_s.split(",") | [peer.state["id"].to_s]
    end

    # Takes whom the leader admitted, as a member, and looks at every other player again.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with what they just told.
    def self.adopt(peer)
      return unless member?(peer.state) && leader.equal?(peer)

      told = told_by(peer)
      if @joining && told.include?(MGQ_MpOverworldSync::Me.id)
        @joining = false
        MGQ_MpCoop.log("#{MGQ_MpOverworldSync.who(peer)} admitted the player to party #{@id}")
      end
      return if told.sort == @admitted.sort

      @admitted = told
      MGQ_MpOverworldSync::Peers.all.each { |other| update(other) unless other.equal?(peer) }
    end

    # As the leader, admits a player who names the party while the invite reaches them, and turns
    # away one it does not reach or who finds the party full.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with what they just told.
    def self.admit(peer)
      player_id = peer.state["id"].to_s
      return @turned_away.delete(player_id) unless @id && peer.state["party"] == @id
      return if player_id.empty? || member?(peer.state) || @turned_away[player_id] || leader != :me

      @turned_away[player_id] = true
      return turn_away(peer, "late") unless invite_reached?(peer.state)
      return turn_away(peer, "full") if full?

      @turned_away.delete(player_id)
      @admitted << player_id
      MGQ_MpCoop.log("admitted #{MGQ_MpOverworldSync.who(peer)} to party #{@id}, whom the invite reached")
    end

    # Notices a player coming into or going out of the party, and stops inviting once one joined.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.update(peer)
      member = member?(peer.state)
      return if member == peer.member

      peer.member = member
      if member
        MGQ_MpCoop.log("#{MGQ_MpOverworldSync.who(peer)} joined party #{@id}")
        close_invite
        MGQ_MpOverworldSync.notice("#{peer.state['name']} joined your party.")
      else
        MGQ_MpCoop.log("#{MGQ_MpOverworldSync.who(peer)} left party #{@id}#{peer.state['party'].to_s.empty? ? '' : ", now naming party #{peer.state['party']}"}")
        @admitted.delete(peer.state["id"].to_s) if leader == :me
        MGQ_MpOverworldSync.notice("#{peer.state['name']} left your party.")
      end
    end

    # Sends a player who names the party away again, as its leader.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @param reason [String] A key of TURNED_AWAY.
    def self.turn_away(peer, reason)
      why = reason == "full" ? "the party is full (#{MGQ_MpCoop.size_of(@id)}/#{MAX_PLAYERS})" : "the invite does not reach them"
      MGQ_MpCoop.log("turned #{MGQ_MpOverworldSync.who(peer)} away from party #{@id}: #{why}")
      MGQ_MpCoop.tell(peer.seat, "kick", reason)
      MGQ_MpOverworldSync.notice("#{peer.state['name']} could not join, #{reason == 'full' ? 'the party is full' : 'the invite is over'}.")
    end

    # Forgets a player who left the world, and a party nobody is left in.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    def self.observe_leaving(peer)
      player_id = peer.state["id"].to_s
      @turned_away.delete(player_id)
      @invites_seen.delete(player_id)
      @admitted.delete(player_id) if leader == :me
      return unless peer.member && members.empty? && !inviting?

      MGQ_MpCoop.log("the last member left the world: forgot party #{@id}")
      forget
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
      inviter = near.find { |peer| peer.state["invite"] == "1" }
      if inviter
        full = Party.full?(inviter.state["party"])
        return option.new("Accept #{inviter.state['name']}'s invite", full ? nil : lambda { Party.join(inviter) }, "The party is full.")
      end
      refusal = invite_refusal("The party is full.")
      return option.new("Invite to a party", nil, refusal) if refusal

      option.new("Invite to a party", near.empty? ? nil : lambda { Party.invite }, "Nobody is near enough to invite.")
    end

    # The choice of a party's member that teleports them to the party's leader, which closes the
    # World overview too.
    #
    # @return [MGQ_MpActions::Option, nil] The choice, nil for the leader and outside a party.
    def self.teleport_option
      lead = MGQ_MpCoop.party_leader
      return nil unless lead.is_a?(MGQ_MpOverworldSync::Peers::Peer) && defined?(MGQ_MpCoopGather)

      MGQ_MpActions::Option.new("Teleport to #{lead.state['name']}", lambda { MGQ_MpCoopGather.join_leader }, nil, nil, true)
    end

    # The wheel's choice that leaves the party, or stops an invite nobody took.
    #
    # @return [MGQ_MpActions::Option] The choice.
    def self.wheel_leave_option
      own_options.first || MGQ_MpActions::Option.new("Leave the party", nil, "You are in no party.")
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
    # them as the party's leader, else inviting them, which only a leader or a player outside a
    # party may.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
    # @return [MGQ_MpActions::Option] The choice.
    def self.peer_option(peer)
      option = MGQ_MpActions::Option
      if Party.invited_by?(peer)
        return option.new("Accept party invite", Party.full?(peer.state["party"]) ? nil : lambda { Party.join(peer) }, "Their party is full.")
      end
      if Party.member?(peer.state)
        return option.new("Remove from party", lambda { Party.remove(peer) }, nil) if Party.leader == :me
        return teleport_option if Party.leader.equal?(peer) && teleport_option

        return option.new("In your party", nil, "#{peer.state['name']} is in your party already.")
      end
      refusal = invite_refusal("Your party is full.")
      return option.new("Invite to party", nil, refusal) if refusal
      return option.new("Invited to party", nil, "Your invite to #{peer.state['name']} stands.") if Party.targets.include?(peer.state["id"].to_s)

      option.new("Invite to party", lambda { Party.invite(peer.state["id"]) }, nil)
    end

    # The party choices on the player's own row of the World overview: leaving the party, and
    # stopping an invite.
    #
    # @return [Array<MGQ_MpActions::Option>] The choices, none outside a party and without an invite.
    def self.own_options
      choices = []
      choices << MGQ_MpActions::Option.new("Leave the party", lambda { Party.leave }, nil) unless Party.members.empty?
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

    # Names what the player is doing for the line above their own head.
    #
    # @return [String, nil] That they invite, nil while they do not.
    def self.own_doing
      Party.inviting? ? "Inviting to a party" : nil
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
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoop.tick(in_world) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoop.state_fields }
  MGQ_MpOverworldSync.on_observe { |peer| MGQ_MpCoop::Party.observe(peer) }
  MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpCoop::Party.observe_leaving(peer) }
  MGQ_MpOverworldSync.label_line { |peer| MGQ_MpCoop.label_line(peer) }
  MGQ_MpCoop.route("kick") { |peer, message| MGQ_MpCoop::Party.removed_by(peer, message["kick"]) }
  # The party chat of ui_chat.rbx, which loads before the party's gate.
  MGQ_MpCoop.route("pchat") { |peer, message| MGQ_MpChat.receive_party(peer, message) }
  # A player declines from outside the party, so their answer passes no party gate.
  MGQ_MpOverworldSync.route("party_decline") { |peer, _message| MGQ_MpCoop::Party.declined_by(peer) if peer }
rescue => e
  MGQ_MpCoop.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# What the party adds to the action wheel, the World overview and the notification box, through
# ui_actions.rbx.

begin
  MGQ_MpActions.offer(MGQ_MpCoop::Offers)
  MGQ_MpActions.wheel_choice(10) { MGQ_MpCoop::Offers.wheel_option }
  MGQ_MpActions.wheel_choice(40) { MGQ_MpCoop::Offers.wheel_leave_option }
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
