#----------------------------------------------------------------
#  coop_teleport.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Named a waiting request in the line above the player's head
#      Paulinchen  2026-10-10: Created
#
#----------------------------------------------------------------

# Teleports between the members of a party, in Classic and Raid Worlds alike. The player asks
# through their state, which names the member and a number of the request; the party's leader lets
# every member come at once, any other member first allows it in the notification box or the World
# overview. The answer tells where they stand, and coop_gather.rbx brings the player over once free.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopTeleport
  # Frames a request stands, a minute: the member first has to notice it in the notification box or
  # the World overview.
  ASK_FRAMES = MGQ_MpCoop::NAMED_INVITE_FRAMES

  # Color of a request in the notification box and the World overview.
  ASK_COLOR = MGQ_MpCoop::INVITE_COLOR

  # Field of the party's messages about teleports.
  FIELD = "ptp"

  # Characters of a request's number.
  NONCE_LENGTH = 6

  # The player's standing request (member id, name, number, frame asked, whether to the leader),
  # nil for none.
  @ask = nil

  # The number of the last request answered, by the id of the member who asked.
  @answered = {}

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "co-op teleport"

  # Reports whether a member is the party's leader, whom every member may teleport to without
  # asking.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [Boolean] Whether they are.
  def self.leader?(peer)
    MGQ_MpCoop.party_leader.equal?(peer)
  end

  # Reports whether the player stands near a member already.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [Boolean] Whether they do.
  def self.near?(peer)
    MGQ_MpCoopGather.near_place?(MGQ_MpCoopGather.own_place, [peer.state["map"].to_i, peer.state["x"].to_i, peer.state["y"].to_i])
  end

  # Reports whether the player's request to a member stands.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [Boolean] Whether it does.
  def self.asking?(peer)
    !@ask.nil? && @ask[:id] == peer.state["id"].to_s
  end

  # Asks to teleport to a member: to the party's leader the player comes at once, to anyone else
  # once they allow it. A newer request replaces the one before.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.ask(peer)
    name = peer.state["name"].to_s
    if near?(peer)
      log("no teleport: the player stands near #{name} already")
      return MGQ_MpOverworldSync.notice("You are with #{name} already.")
    end

    leader = leader?(peer)
    log("replaced the request to #{@ask[:name]}") if @ask
    @ask = { :id => peer.state["id"].to_s, :name => name, :nonce => MGQ_MpCoop.random_id(NONCE_LENGTH),
             :since => Graphics.frame_count, :leader => leader }
    log("asked to teleport to #{MGQ_MpOverworldSync.who(peer)}#{leader ? ', the party\'s leader, who lets the player come at once' : ''} (request #{@ask[:nonce]})")
    MGQ_MpOverworldSync.notice(leader ? "Teleporting to #{name} . . ." : "You asked #{name} to let you teleport to them.")
  rescue => e
    log("asking to teleport failed: #{e.class}: #{e.message}")
  end

  # Takes back the player's request.
  #
  # @param reason [String] Why, for the log.
  def self.stop_asking(reason)
    return unless @ask

    log("took back the request to #{@ask[:name]}: #{reason}")
    @ask = nil
  end

  # The fields the teleports add to the state the player's game tells the others.
  #
  # @return [Hash] "tpask": the id of the member the player asks to teleport to and the request's
  #   number, empty for none.
  def self.state_fields
    { "tpask" => @ask ? "#{@ask[:id]}:#{@ask[:nonce]}" : "" }
  end

  # Reads a member's request to teleport to the player, as their state tells it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
  # @return [String, nil] The request's number, nil for none or one the player answered.
  def self.request_of(peer)
    return nil unless MGQ_MpCoop.in_party? && MGQ_MpCoop::Party.member?(peer.state)

    id, nonce = peer.state["tpask"].to_s.split(":", 2)
    return nil unless id == MGQ_MpOverworldSync::Me.id.to_s && nonce && !nonce.empty?

    @answered[peer.state["id"].to_s] == nonce ? nil : nonce
  end

  # As the party's leader, lets a member who asks come at once. Called whenever a player told their
  # state.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.observe(peer)
    allow(peer) if MGQ_MpCoop.party_leader == :me && request_of(peer)
  rescue => e
    log("answering a request failed: #{e.class}: #{e.message}")
  end

  # Lets a member teleport to the player: tells them where the player stands.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.allow(peer)
    answer(peer, "allow", MGQ_MpCoopGather.place_fields)
  end

  # Declines a member's request.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.decline(peer)
    answer(peer, "deny", {})
  end

  # Answers a member's request, once.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param kind [String] "allow" or "deny".
  # @param fields [Hash] The answer's other fields.
  def self.answer(peer, kind, fields)
    nonce = request_of(peer)
    return log("did not #{kind} #{MGQ_MpOverworldSync.who(peer)}'s request: it no longer stands") unless nonce

    @answered[peer.state["id"].to_s] = nonce
    sent = MGQ_MpCoop.tell(peer.seat, FIELD, kind, fields.merge("nonce" => nonce))
    log("#{kind == 'allow' ? 'allowed' : 'declined'} #{MGQ_MpOverworldSync.who(peer)}'s request #{nonce} to teleport to the player#{sent ? '' : ', which failed to send'}")
  end

  # Takes a member's answer to the player's request, handed over by coop.rbx.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param message [Hash] The message's fields.
  def self.take(peer, message)
    kind = message[FIELD]
    log("got #{kind} from #{MGQ_MpOverworldSync.who(peer)}")
    unless asking?(peer) && @ask[:nonce] == message["nonce"].to_s
      return log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: not the answer to the player's request")
    end

    ask = @ask
    @ask = nil
    case kind
    when "allow" then allowed(peer, ask, [message["map"].to_i, message["x"].to_i, message["y"].to_i, message["d"].to_i], message["warp_ban"] == "1")
    when "deny" then MGQ_MpOverworldSync.notice("#{ask[:name]} declined your teleport.")
    else log("ignored #{kind} from #{MGQ_MpOverworldSync.who(peer)}: unknown kind")
    end
  rescue => e
    log("taking #{message[FIELD]} failed: #{e.class}: #{e.message}")
  end

  # Brings the player to the member who let them come, unless they stand near already.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @param ask [Hash] The player's request.
  # @param place [Array<Integer>] Where the member stands: map, x, y and direction.
  # @param warp_ban [Boolean] Whether warping is banned there.
  def self.allowed(peer, ask, place, warp_ban)
    return log("no teleport: the player stands near #{ask[:name]} already") if MGQ_MpCoopGather.near_place?(MGQ_MpCoopGather.own_place, place)

    MGQ_MpCoopGather.come_to(peer.state["name"].to_s, place, warp_ban)
    MGQ_MpOverworldSync.notice("Teleporting to #{ask[:name]} . . .") unless ask[:leader]
  end

  # Takes back the player's request once its member left the party or let it run out, and forgets
  # everything once the world closes. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    return forget("the world closed") unless in_world
    return unless @ask

    member = MGQ_MpCoop.in_party? && MGQ_MpCoop::Party.members.find { |peer| peer.state["id"].to_s == @ask[:id] }
    return stop_asking("they are no longer in the party") unless member
    return if MGQ_MpCoopGather.within?(@ask[:since], ASK_FRAMES)

    MGQ_MpOverworldSync.notice("#{@ask[:name]} did not answer your teleport.")
    stop_asking("nobody answered in #{ASK_FRAMES / 60} s")
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Forgets the player's request and the requests answered, as when the world closes or a save is
  # loaded.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason)
    stop_asking(reason)
    @answered.clear
  end

  # The choice that teleports the player to a member: at once to the party's leader, else by asking.
  # It closes the World overview too.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [MGQ_MpActions::Option] The choice.
  def self.option(peer)
    name = peer.state["name"].to_s
    text = leader?(peer) ? "Teleport to #{name}" : "Ask to teleport to #{name}"
    return MGQ_MpActions::Option.new(text, nil, "You are with #{name} already.", nil, true) if near?(peer)
    return MGQ_MpActions::Option.new(text, nil, "Your request to #{name} stands.", nil, true) if asking?(peer)

    MGQ_MpActions::Option.new(text, lambda { ask(peer) }, nil, nil, true)
  end

  # What the teleports add to the World overview and the notification box: a member's request, and
  # the teleport to each member.
  module Offers
    # Tells a member's request, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      MGQ_MpCoopTeleport.request_of(peer) ? ["Asks to teleport to you", ASK_COLOR] : nil
    end

    # Tells a member's request for the notification box.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The request, nil for none.
    def self.notice_of(peer)
      nonce = MGQ_MpCoopTeleport.request_of(peer)
      return nil unless nonce

      MGQ_MpActions::Notice.new([:teleport, peer.seat], "#{peer.state['name']} asks to teleport to you", ASK_COLOR, "Allow",
                                lambda { MGQ_MpCoopTeleport.allow(peer) }, lambda { MGQ_MpCoopTeleport.decline(peer) }, nonce)
    end

    # The choice for a member in the World overview: allowing their request, else teleporting to
    # them.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Option, nil] The choice, nil for another player than a member.
    def self.peer_option(peer)
      return nil unless MGQ_MpCoop.in_party? && MGQ_MpCoop::Party.member?(peer.state)
      return MGQ_MpActions::Option.new("Allow teleport", lambda { MGQ_MpCoopTeleport.allow(peer) }, nil) if MGQ_MpCoopTeleport.request_of(peer)

      MGQ_MpCoopTeleport.option(peer)
    end

    # The choices on the player's own row: taking back the player's request.
    #
    # @return [Array<MGQ_MpActions::Option>] The choices, none without a request.
    def self.own_options
      return [] unless MGQ_MpCoopTeleport.asking_name

      [MGQ_MpActions::Option.new("Stop asking to teleport", lambda { MGQ_MpCoopTeleport.stop_asking("the player stopped asking") }, nil)]
    end
  end

  # Names the member the player asks to teleport to.
  #
  # @return [String, nil] Their name, nil without a request.
  def self.asking_name
    @ask ? @ask[:name] : nil
  end

  # Names what the player is doing for the line above their own head: asking a member to let them
  # teleport, with the time the request stands for still. A request to the party's leader is
  # answered at once, so it names nothing.
  #
  # @return [Array, nil] The doing and when it lapses, nil while no request waits.
  def self.own_doing
    return nil unless @ask && !@ask[:leader]

    ["Asking #{@ask[:name]} to teleport", MGQ_MpActions.lapse_at(@ask[:since], ASK_FRAMES)]
  end
end

# What this script takes part in of the party's messages and states, through coop.rbx and
# overworld_sync.rbx, and what it adds to the World overview, the notification box and the line
# above the player's own head, through ui_actions.rbx.

begin
  MGQ_MpCoop.route(MGQ_MpCoopTeleport::FIELD) { |peer, message| MGQ_MpCoopTeleport.take(peer, message) }
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopTeleport.state_fields }
  MGQ_MpOverworldSync.on_observe { |peer| MGQ_MpCoopTeleport.observe(peer) }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoopTeleport.tick(in_world) }
  MGQ_MpActions.offer(MGQ_MpCoopTeleport::Offers)
  MGQ_MpActions.own_doing_from { MGQ_MpCoopTeleport.own_doing }
rescue => e
  MGQ_MpCoopTeleport.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A loaded save starts the frame count anew, so the request of before it goes.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_teleport") { |_contents| MGQ_MpCoopTeleport.forget("a save was loaded") }
rescue => e
  MGQ_MpCoopTeleport.log("hooks FAILED: #{e.class}: #{e.message}")
end
