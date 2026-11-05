#----------------------------------------------------------------
#  notices_test.rb
#
#  Changelog:
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


# Covers MGQ Online's part of the notification box, ui_notices.rbx, on the Mod Framework's box: the
# invites it lists from anywhere in the world while they stand, answered through the DLL, the
# messages the other scripts post, which go with the world they were posted in, the World overview
# hiding the box, the relay's announcement and the notice that Player.ini cannot be read. The box's
# own rules (time, fades, rows, places, hotkeys) are the framework's tests'.

require_relative "world_support"

# Stands in for the World overview, open while $overview_open is.
module MGQ_MpWorldOverview; def self.open?; $overview_open; end; end
# Stands in for the picture the framework measures texts with, each character 7 pixels wide.
class Bitmap
  # The picture's font.
  Font = Struct.new(:name, :size, :color, :bold, :italic, :outline, :out_color, :shadow)
  attr_reader :font
  def initialize(_width = 1, _height = 1); @font = Font.new; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 7, 16); end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
# Stands in for battles_duel.rbx, keeping the answer to a challenge in $duel_answer.
module MGQ_MpBattlesDuel
  # The color a challenge is listed in.
  CHALLENGE_COLOR = Color.new(255, 128, 128)
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
box = notices::BOX
# Runs a frame as the game does: the roots follow it, the buttons' hotkeys, the box, then the frame's end.
frame = lambda { Mod_Framework::UI::Tree.draw_frame; Mod_Framework::UI::ButtonHotkeys.press; box.frame; ui_frame }
frames = lambda { |count| count.times { frame.call } }
# Tells what the box shows: the first offer with its answers as the buttons name them, then the
# other lines.
shown = lambda do
  row = box.instance_variable_get(:@offer_row)
  lines = box.instance_variable_get(:@lines)
  rest = lines ? lines.lines.map { |line| line[:text] } : []
  next rest unless row && row.visible?

  buttons = [:@accept, :@decline].map { |name| box.instance_variable_get(name) }.select { |button| button.visible? }
  [box.instance_variable_get(:@offer_text).text, buttons.map { |button| button.send(:measured_text) }.join("   ")] + rest
end
accept = lambda { $pressed = 0x59; frames.call(2) }
decline = lambda { $pressed = 0x4E; frames.call(2) }
messages = lambda { |key| box.instance_variable_get(:@messages).select { |message| message[:key] == key } }
# Plays the DLL telling whose party invites reach the player, outside a party.
reaching = lambda { |*seats| take_party(nil, [], nil, "inviters" => seats) }

# Nothing to tell.
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
frames.call(2)
check("with nothing to tell, the box shows nothing", [box.box, shown.call], [nil, []])

# An invite and a challenge from afar.
bea = { "id" => "bea", "name" => "Bea", "map" => "9", "x" => "1", "y" => "1", "d" => "2", "scene" => "map", "party" => "bea-p1", "invite" => true, "invite_to" => ["me"] }
cid = { "id" => "cid", "name" => "Cid", "map" => "7", "x" => "1", "y" => "1", "d" => "2", "scene" => "map", "challenge" => "1", "challenge_to" => "me" }
$inbox << entry("in", 3) << entry("message", 3, told(cid)) << entry("in", 2) << entry("message", 2, told(bea))
reaching.call(2)
MGQ_MpOverworldSync.tick
frames.call(2)
check("an invite and a challenge from afar show by the sender's name, the hotkeys on the first", shown.call,
      ["Bea invites you to a party", "Y: Accept   N: Decline", "Cid challenges you to a duel"])

# Declining.
$sounds.clear
$party_calls.clear
decline.call
check("the decline hotkey declines the first invite through the DLL", [$party_calls, $sounds], [[["decline", 2]], ["cancel"]])
frames.call(Mod_Framework::UI::Style::FADE_FRAMES)
check("which stays away while it stands", shown.call, ["Cid challenges you to a duel", "Y: Accept   N: Decline"])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2")))
MGQ_MpOverworldSync.tick
frames.call(2)
check("a new invite of the same player shows again", shown.call.first, "Bea invites you to a party")

# Accepting.
$sounds.clear
$party_calls.clear
$party_answer = party_view("bea-p2", [MGQ_MpOverworldSync::Peers.at(2)], 2, "admitted_me" => false)
accept.call
$party_answer = nil
check("the accept hotkey accepts the first invite through the DLL, taking the party it answers", [$party_calls, MGQ_MpCoop::Party.id, $sounds],
      [[["join", 2]], "bea-p2", ["ok"]])
check("which fades away below the offers that stand", shown.call, ["Cid challenges you to a duel", "Y: Accept   N: Decline", "Bea invites you to a party"])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2", "party_members" => "me", "invite" => false)))
MGQ_MpOverworldSync.tick
frames.call(Mod_Framework::UI::Style::FADE_FRAMES)
check("then the challenge is alone", shown.call, ["Cid challenges you to a duel", "Y: Accept   N: Decline"])

# A challenge in a menu.
SceneManager.scene = Scene_Item.new
frames.call(2)
accept.call
check("in a menu a challenge can only be declined", [shown.call, $duel_answer], [["Cid challenges you to a duel", "N: Decline"], nil])
decline.call
check("which tells the challenger", $duel_answer, [:decline, "Cid", "no"])
SceneManager.scene = Scene_Map.new
$inbox << entry("message", 3, told(cid.merge("challenge" => "0")))
MGQ_MpOverworldSync.tick
frames.call(2)
$inbox << entry("message", 3, told(cid))
MGQ_MpOverworldSync.tick
frames.call(2)

# Where the hotkeys take nothing.
$duel_answer = nil
$overview_open = true
frames.call(2)
accept.call
check("the World overview hides the box, and the hotkeys take nothing there", [notices.shown?, $duel_answer], [false, nil])
$overview_open = false
frames.call(2)
check("closed, the box shows again with the challenge first", [notices.shown?, shown.call.first], [true, "Cid challenges you to a duel"])
$mgq_text_input = true
accept.call
$mgq_text_input = false
check("the hotkeys type instead while the player types", $duel_answer, nil)
Mod_Framework::UI::Capture.start(:trade)
frames.call(2)
accept.call
Mod_Framework::UI::Capture.stop(:trade)
frames.call(2)
check("and take nothing while a screen of the mod holds the game's buttons", $duel_answer, nil)

# An accept the inviter's game turns down.
accept.call
check("otherwise the accept hotkey accepts the challenge on the map", $duel_answer, [:accept, "Cid"])
$duel_answer = nil
accept.call
check("which then stays away, only fading, so another press accepts nothing", [shown.call, $duel_answer], [["Cid challenges you to a duel"], nil])
notices.release([:duel, 3])
frames.call(2)
accept.call
check("until the inviter turns the accept down, which shows it again at once", $duel_answer, [:accept, "Cid"])

# Messages and the world.
notices.message(:soon, "Bea is in a battle!", 120)
check("a message shows for the frames it is given, in the world's group", messages.call(:soon).map { |message| [message[:left], message[:group]] },
      [[120, :mgq_online_world]])
notices.drop(:soon, "a test")
check("and drop takes it away", messages.call(:soon), [])
notices.message(:in_world, "Gone with the world")
$open = false
MGQ_MpOverworldSync.tick
notices.message(:world_invite, "Discord invite taken")
MGQ_MpOverworldSync.tick
frames.call(2)
check("leaving the world takes its invites and its messages, and a message posted outside stays", shown.call, ["Discord invite taken"])
check("posted outside a world, it has no group", messages.call(:world_invite).map { |message| message[:group] }, [nil])
notices.drop(:world_invite)
$open = true

# The relay's announcement.
notices.announce("The relay restarts in ten minutes for an update. Finish your battles and stay on the map please.")
notices.announce("Short news.")
check("an announcement is one wrapped message for ten seconds, a newer one in its place",
      messages.call(notices::ANNOUNCEMENT_KEY).map { |message| [message[:text], message[:wrap], message[:left]] }, [["Short news.", true, 600]])

# The notice that Player.ini cannot be read.
player_ini = "Player.ini could not be read; close programs that hold it. Settings are not saved until then."
$player_ini_notice = player_ini
2.times { MGQ_MpOverworldSync.tick }
check("the notice that Player.ini cannot be read shows, posted once", messages.call(notices::PLAYER_INI_KEY).map { |message| message[:text] }, [player_ini])
check("the box failed nowhere", $framework_log.grep(/^notices: .*FAILED/), [])
