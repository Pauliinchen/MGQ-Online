#----------------------------------------------------------------
#  coop_teleport.rbx
#
#  Changelog:
#      Paulinchen  2026-10-31: Stopped carrying the warp ban of the member's place along
#      Paulinchen  2026-10-30: Left the requests, their answers, their minute and their texts to the DLL, and read its view
#      Paulinchen  2026-10-11: Named a waiting request in the line above the player's head
#      Paulinchen  2026-10-10: Created
#
#----------------------------------------------------------------

# Teleports between the members of a party, in Classic and Raid Worlds alike. The requests are the
# DLL's (MGQOnline.Game's TeleportRequests): the player asks through their state, which names the
# member and a number of the request; the party's leader lets every member come at once, any other
# member first allows it in the notification box or the World overview. The answer tells where they
# stand, and coop_gather.rbx brings the player over once free. This script hands the DLL the
# player's place and actions, and reads the view it answers once a frame.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpCoopTeleport
  # Color of a request in the notification box and the World overview.
  ASK_COLOR = MGQ_MpCoop::INVITE_COLOR

  # The topic that asks to teleport to a member.
  ASK_TOPIC = "tp.ask"

  # The topic that lets a member come.
  ALLOW_TOPIC = "tp.allow"

  # The topic that declines a member's request.
  DECLINE_TOPIC = "tp.decline"

  # The topic that takes the player's request back.
  STOP_TOPIC = "tp.stop"

  # The topic that forgets the request and the requests answered.
  FORGET_TOPIC = "tp.forget"

  # The topic that takes the player's place and answers the view.
  VIEW_TOPIC = "tp.view"

  # The view outside a world and while the DLL does not answer: no request, no offers.
  NONE = { "tpask" => "", "doing" => nil, "own" => [], "members" => {} }

  # The view as the DLL answered it last.
  @view = NONE

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "co-op teleport"

  # Takes the view the DLL answered.
  #
  # @param view [Hash, nil] The view, see NONE for its fields; nil for none.
  def self.take_view(view)
    @view = view.is_a?(Hash) ? view : NONE
  end

  # Asks the DLL for an action, and takes the view it answers.
  #
  # Keeps the last view when the action fails, since the DLL then answers the next frame's view only
  # once it changes.
  #
  # @param topic [String] The action's topic.
  # @param request [Object] What it takes.
  def self.act(topic, request)
    view = MGQ_Multiplayer::Bridge.call(topic, request)
    take_view(view) if view.is_a?(Hash)
  end

  # Reads what the view offers with a member.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [Hash, nil] "text", "refusal", "request", "allow", "call", "notice" and "action"; nil
  #   for another player than a member.
  def self.row(peer)
    @view["members"][peer.seat]
  end

  # Asks to teleport to a member: to the party's leader the player comes at once, to anyone else
  # once they allow it.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.ask(peer)
    act(ASK_TOPIC, peer.seat)
  rescue => e
    log("asking to teleport failed: #{e.class}: #{e.message}")
  end

  # Takes back the player's request.
  #
  # @param reason [String] Why, for the log.
  def self.stop_asking(reason)
    act(STOP_TOPIC, reason)
  end

  # Forgets the player's request and the requests answered, as when a save is loaded.
  #
  # @param reason [String] Why, for the log.
  def self.forget(reason)
    act(FORGET_TOPIC, reason)
  end

  # The fields the teleports add to the state the player's game tells the others.
  #
  # @return [Hash] "tpask": the id of the member the player asks to teleport to and the request's
  #   number, empty for none.
  def self.state_fields
    { "tpask" => @view["tpask"].to_s }
  end

  # Lets a member teleport to the player: tells them where the player stands.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.allow(peer)
    act(ALLOW_TOPIC, "seat" => peer.seat, "place" => MGQ_MpCoopGather.place_fields)
  end

  # Declines a member's request.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  def self.decline(peer)
    act(DECLINE_TOPIC, peer.seat)
  end

  # Brings the player to the member who let them come, as the DLL tells.
  #
  # @param event [Hash] "name", "map", "x", "y" and "d".
  def self.allowed(event)
    MGQ_MpCoopGather.come_to(event["name"].to_s, [event["map"], event["x"], event["y"], event["d"]])
  rescue => e
    log("teleporting failed: #{e.class}: #{e.message}")
  end

  # Hands the DLL where the player stands and reads the view once it changed, once a frame while a
  # world is open. Called every frame in every scene.
  #
  # @param in_world [Boolean] Whether a world is open.
  def self.tick(in_world)
    return take_view(nil) unless in_world && $game_map && $game_player

    view = MGQ_Multiplayer::Bridge.call(VIEW_TOPIC, MGQ_MpCoopGather.place_fields)
    take_view(view) if view.is_a?(Hash)
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # The choice that teleports the player to a member: at once to the party's leader, else by asking.
  # It closes the World overview too.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The member.
  # @return [MGQ_MpActions::Option, nil] The choice, nil for another player than a member.
  def self.option(peer)
    found = row(peer)
    return nil unless found
    return MGQ_MpActions::Option.new(found["text"], nil, found["refusal"], nil, true) if found["refusal"]

    MGQ_MpActions::Option.new(found["text"], lambda { ask(peer) }, nil, nil, true)
  end

  # What the teleports add to the World overview and the notification box: a member's request, and
  # the teleport to each member.
  module Offers
    # Tells a member's request, when it reaches the player.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [Array, nil] The text and its color, nil for none.
    def self.call_of(peer)
      found = MGQ_MpCoopTeleport.row(peer)
      found && found["call"] ? [found["call"], ASK_COLOR] : nil
    end

    # Tells a member's request for the notification box.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Notice, nil] The request, nil for none.
    def self.notice_of(peer)
      found = MGQ_MpCoopTeleport.row(peer)
      return nil unless found && found["request"]

      MGQ_MpActions::Notice.new([:teleport, peer.seat], found["notice"], ASK_COLOR, found["action"],
                                lambda { MGQ_MpCoopTeleport.allow(peer) }, lambda { MGQ_MpCoopTeleport.decline(peer) }, found["request"])
    end

    # The choice for a member in the World overview: allowing their request, else teleporting to
    # them.
    #
    # @param peer [MGQ_MpOverworldSync::Peers::Peer] The other player.
    # @return [MGQ_MpActions::Option, nil] The choice, nil for another player than a member.
    def self.peer_option(peer)
      found = MGQ_MpCoopTeleport.row(peer)
      return nil unless found
      return MGQ_MpActions::Option.new(found["allow"], lambda { MGQ_MpCoopTeleport.allow(peer) }, nil) if found["request"]

      MGQ_MpCoopTeleport.option(peer)
    end

    # The choices on the player's own row: taking back the player's request.
    #
    # @return [Array<MGQ_MpActions::Option>] The choices, none without a request.
    def self.own_options
      MGQ_MpCoopTeleport.own_texts.map { |text| MGQ_MpActions::Option.new(text, lambda { MGQ_MpCoopTeleport.stop_asking("the player stopped asking") }, nil) }
    end
  end

  # Lists the texts of the choices on the player's own row.
  #
  # @return [Array<String>] The texts.
  def self.own_texts
    @view["own"]
  end

  # Names what the player is doing for the line above their own head: asking a member to let them
  # teleport, with the time the request stands for still. A request to the party's leader is
  # answered at once, so it names nothing.
  #
  # @return [Array, nil] The doing and when it lapses, nil while no request waits.
  def self.own_doing
    doing = @view["doing"]
    doing ? [doing["text"], MGQ_MpActions.lapse_in(doing["ends"] - MGQ_Multiplayer::Bridge.frame_number)] : nil
  end
end

# What this script takes part in of the party's states and the DLL's events, through
# overworld_sync.rbx and the bridge, and what it adds to the World overview, the notification box
# and the line above the player's own head, through ui_actions.rbx.

begin
  MGQ_MpOverworldSync.state_fields { MGQ_MpCoopTeleport.state_fields }
  MGQ_MpOverworldSync.on_tick { |in_world| MGQ_MpCoopTeleport.tick(in_world) }
  MGQ_Multiplayer::Bridge.on("tp.allowed") { |event| MGQ_MpCoopTeleport.allowed(event) }
  MGQ_Multiplayer::Bridge.on("tp.notice") { |text| MGQ_MpOverworldSync.notice(text.to_s) }
  MGQ_MpActions.offer(MGQ_MpCoopTeleport::Offers)
  MGQ_MpActions.own_doing_from { MGQ_MpCoopTeleport.own_doing }
rescue => e
  MGQ_MpCoopTeleport.log("co-op FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone, through core_hooks.rbx.

begin
  # A loaded save starts the game anew, so the request of before it goes.
  MGQ_MpHooks.after(DataManager.singleton_class, :extract_save_contents, "coop_teleport") { |_contents| MGQ_MpCoopTeleport.forget("a save was loaded") }
rescue => e
  MGQ_MpCoopTeleport.log("hooks FAILED: #{e.class}: #{e.message}")
end
