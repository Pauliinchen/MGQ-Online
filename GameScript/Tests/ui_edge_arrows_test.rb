#----------------------------------------------------------------
#  ui_edge_arrows_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Reached the Mod Framework's engine under its own name
#                            - Checked the arrows shown and what they say, leaving how they look to the in-game suite
#      Paulinchen  2026-11-01: Checked the arrows as markers of the Mod Framework, the players picked by the DLL's stand-in
#                            - Hid the arrows behind any mod's screen that holds the game, as the Mod Framework tells
#      Paulinchen  2026-10-31: Took a player's color from MGQ_MpPlayerColor and the strip at the top from MGQ_MpHud
#      Paulinchen  2026-10-30: Dropped the checks that restate pixel positions
#      Paulinchen  2026-10-11: Checked that a preset change draws an arrow anew
#                            - Checked that a player outside the party gets a plain white arrow
#                            - Created
#
#----------------------------------------------------------------

# Covers the arrows at the screen's edge, ui_edge_arrows.rbx: what the map tells the DLL's pick
# (hud.arrows, whose rules and log MGQOnline.Game.Tests checks against their golden cases), what
# hides every arrow, and the arrows shown, kept and taken away as the DLL picks players, with what
# they say.

require_relative "hud_support"

$logs = []
# The mod's log, kept in $logs and printed with the checks.
module MGQ_Multiplayer; module Log; def self.write(m); $logs << m; puts "  log: #{m}"; end; end; end

# The map's view, from which a character's place on the screen follows.
# The map, with its view's origin in tiles.
class Game_Map; attr_accessor :display_x, :display_y; end
$game_map.display_x = $game_map.display_y = 0
# The game's character, placed on the screen by the map's view at 32 pixels a tile.
class Game_Character
  # The middle of its tile across the screen.
  def screen_x; (@x - $game_map.display_x) * 32 + 16; end
  # The bottom of its tile on the screen.
  def screen_y; (@y - $game_map.display_y) * 32 + 32; end
end
# Another player's ghost on the map.
class Ghost < Game_Character; end


load_script "ui_edge_arrows"

# Stands in for the DLL's pick: each request kept in $arrow_requests, the seats in $picked answered.
$arrow_requests = []
$picked = []
$forgotten = 0
$world_bridge.answer(MGQ_MpEdgeArrows::ARROWS_TOPIC) { |request| $arrow_requests << request; request["reason"] ? [] : $picked }
$world_bridge.answer(MGQ_MpEdgeArrows::FORGET_TOPIC) { |_request| $forgotten += 1; nil }

# The script under test.
Arrows = MGQ_MpEdgeArrows

# Puts another player on the map with a ghost standing on a tile.
#
# @param seat [Integer] Their seat.
# @param id [String] Their id.
# @param name [String] Their name.
# @param x [Integer] The tile's x.
# @param y [Integer] The tile's y.
# @param member [Boolean] Whether they are in the player's party.
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def arrive(seat, id, name, x, y, member = false)
  MGQ_MpOverworldSync::Peers.take(seat, { "id" => id, "name" => name, "map" => 5, "x" => x, "y" => y })
  peer = MGQ_MpOverworldSync::Peers.at(seat)
  peer.member = member
  peer.ghost = Ghost.new
  peer.ghost.moveto(x, y)
  peer
end

# Walks a player's ghost to a tile.
#
# @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
# @param x [Integer] The tile's x.
# @param y [Integer] The tile's y.
def walk(peer, x, y)
  peer.state["x"] = x
  peer.state["y"] = y
  peer.ghost.moveto(x, y)
end

# The player stands on tile 3, 4 with the map's view at its origin.

# What the map tells the DLL's pick.
member = arrive(2, "aa-member", "Member", 40, 4, true)
stranger = arrive(3, "bb-stranger", "Stranger", 3, 40)
ghostless = arrive(4, "cc-ghostless", "Ghostless", 5, 4, true)
ghostless.ghost = nil
member.state["hidden"] = 1
Arrows.pick(nil)
check("the DLL hears the screen and each ghost on the map with its place, tiles and color, a transparent one too, a player without a ghost left out",
      $arrow_requests.last, { "reason" => nil, "screen" => [640, 480], "ghosts" => { 2 => [1296, 160, 37, "member"], 3 => [112, 1312, 36, "plain"] } })
member.state.delete("hidden")
$picked = [3, 2, 4, 9]
check("and answers the players nearest first, a seat without a ghost or a player left out", Arrows.pick(nil).map { |peer| peer.state["id"] }, ["bb-stranger", "aa-member"])
MGQ_MpOverworldSync::Peers.clear

# What hides every arrow: any mod's screen that holds the game, as Mod_Framework::UI.busy? tells.
covered = "a screen of a mod lies over the map"
check("nothing hides the arrows on a quiet map in a world", Arrows.hidden_reason, nil)
$open = false
check("outside a world", Arrows.hidden_reason, "no world is open")
$open = true
Mod_Framework::UI::Engine::Capture.start(:a_wheel)
check("a wheel or the World overview, which hold the game's buttons", Arrows.hidden_reason, covered)
Mod_Framework::UI::Engine::Capture.stop(:a_wheel)
$mgq_text_input = true
check("the chat box, which types", Arrows.hidden_reason, covered)
$mgq_text_input = nil
$game_message.busy = true
check("a message", Arrows.hidden_reason, "a message shows")
$game_message.busy = false

# The arrows, through the map's hooks.
spriteset = Spriteset_Map.new
# Lists the players whose arrows show, by id.
shown = lambda { MGQ_MpShown.keys_of(:edge_arrow).map { |key| key[1] } }
$picked = []
spriteset.update
check("the map's update shows no arrow while the DLL picks nobody", shown.call, [])
member = arrive(2, "aa-member", "Member", 40, 4, true)
$picked = [2]
spriteset.update
member_peer = MGQ_MpOverworldSync::Peers.at(2)
check("a member the DLL picks gets an arrow, in the members' color, with their name and tiles",
      [shown.call, Arrows.label_of(member_peer), MGQ_MpPlayerColor.role(member_peer)], [["aa-member"], "Member 37", :mgq_online_member])
walk(member, 40, 40)
spriteset.update
check("a ghost that moves keeps its arrow, the tiles counted anew", [shown.call, Arrows.label_of(member_peer)], [["aa-member"], "Member 73"])

stranger = arrive(3, "bb-stranger", "Long Name Player Seven", 3, 40)
$picked = [3, 2]
spriteset.update
stranger_peer = MGQ_MpOverworldSync::Peers.at(3)
check("a second player gets a second arrow, in plain text as a player outside the party, a long name cut before the tiles",
      [shown.call.sort, MGQ_MpPlayerColor.role(stranger_peer), Arrows.label_of(stranger_peer)], [["aa-member", "bb-stranger"], :text, "Long Name... 36"])

$mgq_text_input = true
spriteset.update
check("the chat box hides every arrow, which keep their players, and the DLL hears why with no ghosts",
      [shown.call.size, Arrows.hidden_reason, $arrow_requests.last.values_at("reason", "ghosts")], [2, covered, [covered, {}]])
$mgq_text_input = nil
spriteset.update
check("closing it shows them again", [shown.call.size, Arrows.hidden_reason], [2, nil])

$picked = [3]
spriteset.update
check("a player the DLL no longer picks loses their arrow", shown.call, ["bb-stranger"])
$picked = [3, 2]
spriteset.update
check("picked again, they get one again", shown.call.sort, ["aa-member", "bb-stranger"])

# A failing frame is logged once, takes every arrow away and the map goes on.
MGQ_MpOverworldSync::Peers.at(2).ghost = Object.new
2.times { spriteset.update }
check("a frame that fails is logged once and takes the arrows away", [$logs.count { |line| line.start_with?("edge arrows: the arrows failed: NoMethodError") }, shown.call], [1, []])
MGQ_MpOverworldSync::Peers.at(2).ghost = Ghost.new
MGQ_MpOverworldSync::Peers.at(2).ghost.moveto(40, 4)
spriteset.update
spriteset.dispose
check("the map's dispose takes the arrows away and has the DLL forget which it logged", [shown.call, $forgotten], [[], 1])
