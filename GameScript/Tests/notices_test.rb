#----------------------------------------------------------------
#  notices_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked the offers and toasts the facade hands the framework's notice stack, leaving the stack to the framework
#      Paulinchen  2026-11-05: Handed the other players' states as the DLL reads them
#      Paulinchen  2026-11-01: Checked the invites, the world's messages, the World overview and the announcement on the Mod Framework's notification box
#                            - Left the check of the Mod Framework's settings notice to the Mod Framework's tests
#      Paulinchen  2026-10-31: Read Accept and Decline as the Mod Framework's hotkeys and checked the accept key while a question box is open
#                            - Checked the notice that the Mod Framework's settings cannot be read
#                            - Kept the boxes' places in the Mod Framework's settings
#                            - Checked that a message posted while the box hides counts its time only once it shows
#      Paulinchen  2026-10-30: Dropped the fade checks
#      Paulinchen  2026-10-23: Told the invites that reach the player and the party's actions through the DLL's party view
#      Paulinchen  2026-10-22: Checked the relay's announcement in the box's rows, in place of the one before
#      Paulinchen  2026-10-12: Checked that the box at its default lies 4 pixels below the Leader HUD
#                            - Checked the log of the accept hotkey while typing and when refused
#                            - Checked that the box at its default moves below the Leader HUD
#      Paulinchen  2026-10-11: Checked the box's place and size in the layout and a redraw after a preset change
#                            - Checked the box's fades, the row of more waiting and a long notification cut
#                            - Checked the hotkeys drawn whole with a rebound hotkey's longer name
#      Paulinchen  2026-10-08: Checked that an accepted invite shows again while it stands, a declined one not
#                            - Checked that an accepted invite stays away for the whole hold
#      Paulinchen  2026-10-07: Checked that an accepted invite stays away while it stands
#      Paulinchen  2026-10-06: Checked that a message shown outside a world shows there and goes after a moment
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Offered the challenges through MGQ_MpActions, as the duel script does
#                            - Created
#
#----------------------------------------------------------------


# Covers MGQ Online's part of the framework's notice stack, ui_notices.rbx: the invites it offers
# from anywhere in the world while they stand, answered through the DLL, the messages the other
# scripts post as toasts, which go with the world they were posted in, the World overview hiding
# the stack, the relay's announcement and the notice that Player.ini cannot be read. The stack's
# own rules (time, fades, rows, hotkeys) are the framework's tests' and the in-game suite's.

require_relative "world_support"

# Stands in for the World overview, open while $overview_open is.
module MGQ_MpWorldOverview; def self.open?; $overview_open; end; end
# Stands in for battles_duel.rbx, keeping the answer to a challenge in $duel_answer.
module MGQ_MpBattlesDuel
  # The color a challenge is listed in.
  CHALLENGE_COLOR = :mgq_online_own
  def self.available?; true; end
  def self.challenged_by?(peer); peer.state["challenge"] == "1"; end
  def self.accept(peer); $duel_answer = [:accept, peer.state["name"]]; end
  def self.decline(peer, reason); $duel_answer = [:decline, peer.state["name"], reason]; end

  # The challenges the notification box lists, as battles_duel.rbx offers them.
  module Offers
    # Lists a player's challenge, which only the map lets the player accept.
    #
    # @param peer [Object] The challenging player.
    # @return [MGQ_MpActions::Notice, nil] The notice, nil without a challenge.
    def self.notice_of(peer)
      duel = MGQ_MpBattlesDuel
      return nil unless duel.challenged_by?(peer)

      on_map = SceneManager.scene.is_a?(Scene_Map)
      MGQ_MpActions::Notice.new([:duel, peer.seat], "#{peer.state['name']} challenges you to a duel", CHALLENGE_COLOR, on_map ? "Accept" : nil,
                                on_map ? lambda { duel.accept(peer) } : nil, lambda { duel.decline(peer, "no") }, peer.state["id"])
    end
  end
end
MGQ_MpActions.offer(MGQ_MpBattlesDuel::Offers)

load_script "ui_notices"

notices = MGQ_MpNotices
# The framework's calls the facade makes, each noted in $calls.
$calls = []
Mod_Framework.define_singleton_method(:toast) { |text, options = {}| $calls << [:toast, text, options]; nil }
ui = Mod_Framework::UI
[:drop_toast, :drop_group, :release_offer].each { |name| ui.define_singleton_method(name) { |key| $calls << [name, key]; nil } }
# Lists the invites the stack offers now: each one's text, whether it can be accepted and the
# accept's name.
offered = lambda { notices.invites.map { |offer| [offer[:text], offer[:accept] ? true : false, offer[:accept_text]] } }
# Answers the first offer as the stack's Accept or Decline does.
answer = lambda { |which| notices.invites.first[which].call }
# Plays the DLL telling whose party invites reach the player, outside a party.
reaching = lambda { |*seats| take_party(nil, [], nil, "inviters" => seats) }

# Nothing to tell.
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
check("with nothing to tell, the stack lists no invite", notices.invites, [])

# An invite and a challenge from afar.
bea = { "id" => "bea", "name" => "Bea", "map" => "9", "x" => "1", "y" => "1", "d" => "2", "scene" => "map", "party" => "bea-p1", "invite" => true, "invite_to" => ["me"] }
cid = { "id" => "cid", "name" => "Cid", "map" => "7", "x" => "1", "y" => "1", "d" => "2", "scene" => "map", "challenge" => "1", "challenge_to" => "me" }
$inbox << entry("in", 3) << entry("message", 3, told(cid)) << entry("in", 2) << entry("message", 2, told(bea))
reaching.call(2)
MGQ_MpOverworldSync.tick
check("an invite and a challenge from afar are offered by the sender's name, each with its Accept, in the world's group",
      [offered.call, notices.invites.map { |offer| offer[:group] }],
      [[["Bea invites you to a party", true, "Accept"], ["Cid challenges you to a duel", true, "Accept"]], [:mgq_online_world] * 2])

# Declining and accepting answer through the DLL.
$party_calls.clear
answer.call(:decline)
check("Decline declines the invite through the DLL", $party_calls, [["decline", 2]])
$party_calls.clear
$party_answer = party_view("bea-p2", [MGQ_MpOverworldSync::Peers.at(2)], 2, "admitted_me" => false)
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2")))
MGQ_MpOverworldSync.tick
answer.call(:accept)
$party_answer = nil
check("Accept accepts a new invite through the DLL, taking the party it answers", [$party_calls, MGQ_MpCoop::Party.id], [[["join", 2]], "bea-p2"])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2", "party_members" => "me", "invite" => false)))
MGQ_MpOverworldSync.tick
check("then the challenge is alone", offered.call, [["Cid challenges you to a duel", true, "Accept"]])

# A challenge in a menu.
SceneManager.scene = Scene_Item.new
check("in a menu a challenge can only be declined", offered.call, [["Cid challenges you to a duel", false, nil]])
answer.call(:decline)
check("which tells the challenger", $duel_answer, [:decline, "Cid", "no"])
SceneManager.scene = Scene_Map.new

# The World overview hides the stack.
$overview_open = true
check("the World overview hides the stack", notices.shown?, false)
$overview_open = false
check("closed, the stack shows again", notices.shown?, true)

# An accept the inviter's game turns down shows the invite again at once.
notices.release([:duel, 3])
check("release has the framework show the accepted invite again", $calls.last, [:release_offer, [:duel, 3]])

# Messages and the world.
$calls.clear
notices.message(:soon, "Bea is in a battle!", 120)
check("a message is a toast for the seconds of its frames, in the world's group", $calls.last,
      [:toast, "Bea is in a battle!", { :key => :soon, :seconds => 2.0, :group => :mgq_online_world }])
notices.drop(:soon, "a test")
check("and drop takes it away", $calls.last, [:drop_toast, :soon])
$open = false
MGQ_MpOverworldSync.tick
check("leaving the world takes its invites and its messages", [$calls.last, notices.invites], [[:drop_group, :mgq_online_world], []])
notices.message(:world_invite, "Discord invite taken")
check("a message posted outside a world has no group and the toasts' own time", $calls.last, [:toast, "Discord invite taken", { :key => :world_invite }])
$open = true

# The relay's announcement.
notices.announce("Short news.")
check("an announcement is a toast for ten seconds, a newer one in its place", $calls.last,
      [:toast, "Short news.", { :key => notices::ANNOUNCEMENT_KEY, :seconds => notices::ANNOUNCEMENT_SECONDS }])

# The notice that Player.ini cannot be read.
player_ini = "Player.ini could not be read; close programs that hold it. Settings are not saved until then."
$player_ini_notice = player_ini
$calls.clear
2.times { MGQ_MpOverworldSync.tick }
check("the notice that Player.ini cannot be read shows, posted once", $calls.select { |call| call[0] == :toast }.map { |call| call[1] }, [player_ini])
