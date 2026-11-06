#----------------------------------------------------------------
#  ui_edge_arrows.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Made each arrow a marker of the Mod Framework's UI layer
#      Paulinchen  2026-11-01: Made each arrow a marker of the Mod Framework, the players picked and logged by the DLL
#                            - Hid the arrows while any mod's screen holds the game, as the Mod Framework tells
#      Paulinchen  2026-10-31: Took a player's color from MGQ_MpPlayerColor and the strip at the top from MGQ_MpHud
#      Paulinchen  2026-10-23: Kept the arrows off the live map behind menus
#      Paulinchen  2026-10-12: Read the map's viewport through MGQ_MpGame
#      Paulinchen  2026-10-11: Drew an arrow's plate anew once the preset changes
#                            - Created
#
#----------------------------------------------------------------

# Arrows at the screen's edge toward the players on the map whose ghost is off the screen: a small
# filled triangle in the player's color where the line from the player's sprite to them crosses
# the edge, with their name and how many tiles away they are on a plate inside the screen. Party
# members get one always, everyone else only in a Raid World, the nearest eight at most. A player in
# a menu or a battle, whose ghost is drawn transparent, keeps their arrow: it is them the others
# look for. The arrows hide while a wheel, the World overview or the chat box is open, while a
# message shows, and outside a world, fading in and out.
#
# The DLL picks the players and logs the arrows coming and going (hud.arrows); each arrow is a
# marker of the Mod Framework's UI layer, which places and draws it.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpEdgeArrows
  # The topic that picks the players the arrows point at, HudTopics.ArrowsTopic.
  ARROWS_TOPIC = "hud.arrows"

  # The topic that forgets which arrows were logged, HudTopics.ForgetTopic.
  FORGET_TOPIC = "hud.arrows_forget"

  # Characters a player's name may take on the plate before it is cut.
  NAME_CHARS = 12

  # How the plate reads: the name, then the tiles away.
  LABEL = "%s %d"

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "edge arrows"

  # The Mod Framework's interface.
  UI = Mod_Framework::UI

  # Tells why no arrow shows now.
  #
  # @return [String, nil] The reason, nil while the arrows may show.
  def self.hidden_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?
    return "a screen of a mod lies over the map" if Mod_Framework::UI.busy?
    return "a message shows" if $game_message && $game_message.busy?

    nil
  end

  # Lists the ghosts on the player's map for the DLL's pick: each player's ghost where it shows on
  # the screen, how many tiles away it stands and the name of its player's color.
  #
  # @return [Hash{Integer => Array}] [screen x, screen y, tiles, color's name] by seat.
  def self.ghosts
    found = {}
    MGQ_MpOverworldSync::Peers.all.each do |peer|
      ghost = peer.ghost
      next unless ghost

      found[peer.seat] = [ghost.screen_x.to_i, ghost.screen_y.to_i, tiles_to(ghost), MGQ_MpPlayerColor.label(peer)]
    end
    found
  end

  # Counts the tiles to walk to a ghost, the map's loop taken into account.
  #
  # @param ghost [Game_MpGhost] The ghost.
  # @return [Integer] The tiles.
  def self.tiles_to(ghost)
    ghost.distance_x_from($game_player.x).abs + ghost.distance_y_from($game_player.y).abs
  end

  # Asks the DLL which players the arrows point at this frame, which logs why they hide and the
  # arrows coming and going.
  #
  # @param reason [String, nil] Why no arrow shows, see hidden_reason.
  # @return [Array<MGQ_MpOverworldSync::Peers::Peer>] The players, nearest first.
  def self.pick(reason)
    seats = MGQ_Multiplayer::Bridge.call(ARROWS_TOPIC, "reason" => reason, "screen" => [Graphics.width, Graphics.height], "ghosts" => reason ? {} : ghosts)
    Array(seats).map { |seat| MGQ_MpOverworldSync::Peers.at(seat) }.select { |peer| peer && peer.ghost }
  end

  # Writes what an arrow's plate reads: the name over the player's ghost, cut, and the tiles away.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @return [String] Such as "Ana 12".
  def self.label_of(peer)
    name = MGQ_MpOverworld.name_tag(peer)
    name = "#{name[0, NAME_CHARS - 3]}..." if name.size > NAME_CHARS
    ghost = peer.ghost
    format(LABEL, name, ghost ? tiles_to(ghost) : 0)
  end

  # Points the arrows at the players the DLL picks and takes the others away; while a reason
  # hides them they keep their players and hide. Called by the map's sprites every frame.
  def self.update
    reason = hidden_reason
    picked = pick(reason)
    return if reason

    ids = picked.map { |peer| peer.state["id"].to_s }
    MGQ_MpShown.keys_of(:edge_arrow).each { |key| MGQ_MpShown.drop(key) unless ids.include?(key[1]) }
    picked.each { |peer| MGQ_MpShown.keep([:edge_arrow, peer.state["id"].to_s], EdgeArrow, peer: peer) }
  rescue => e
    log_once(:update, "the arrows failed: #{e.class}: #{e.message}")
    drop_all
  end

  # Takes every arrow away and has the DLL forget which it logged, with the map's sprites.
  def self.dispose
    drop_all
    MGQ_Multiplayer::Bridge.call(FORGET_TOPIC)
  end

  # Takes every arrow away.
  def self.drop_all
    MGQ_MpShown.keys_of(:edge_arrow).each { |key| MGQ_MpShown.drop(key) }
  end

  # A player's arrow: a marker of the Mod Framework's UI layer toward their ghost's tile, in their
  # color, with their name and the tiles away; it hides while hidden_reason holds.
  class EdgeArrow < UI::Component
    # The player.
    param :peer

    # Describes the arrow.
    def render
      marker target: -> { tile }, text: -> { MGQ_MpEdgeArrows.label_of(peer) }, color: -> { MGQ_MpPlayerColor.role(peer) },
             hide_while: -> { !MGQ_MpEdgeArrows.hidden_reason.nil? }
    end

    private

    # Tells the tile the player's ghost stands on.
    #
    # @return [Array<Integer>] The tile, where it stood last once the ghost is gone.
    def tile
      ghost = peer.ghost
      @tile = [ghost.x, ghost.y] if ghost
      @tile || [0, 0]
    end
  end
end

begin
  # After the map's sprites, the arrows toward the players off the screen, never on the map behind
  # a menu.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_edge_arrows") { MGQ_MpEdgeArrows.update if mgq_mp_hud? }

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_edge_arrows") { MGQ_MpEdgeArrows.dispose if mgq_mp_hud? }
rescue => e
  MGQ_MpEdgeArrows.log("hooks FAILED: #{e.class}: #{e.message}")
end
