#----------------------------------------------------------------
#  notices_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-07: Checked that an accepted invite stays away while it stands
#      Paulinchen  2026-10-06: Checked that a message shown outside a world shows there and goes after a moment
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Offered the challenges through MGQ_MpActions, as the duel script does
#                            - Created
#
#----------------------------------------------------------------

# Covers the notification box, ui_notices.rbx: the invites it lists from anywhere in the world while
# they stand, the messages it shows for a moment, the scenes it shows in, and its keys.

require_relative "world_support"

# Stand-ins for the game's pictures, the World overview and duels.
class Bitmap
  Font = Struct.new(:outline, :size, :color)
  attr_reader :texts, :font
  def initialize(*); @texts = []; @font = Font.new; end
  def clear; @texts = []; end
  def fill_rect(*); end
  def draw_text(_x, _y, _width, _height, text, _align = 0); @texts << text; end
  def dispose; end
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :visible
  def disposed?; false; end
  def dispose; end
end
module MGQ_MpWorldOverview; def self.open?; $overview_open; end; end
module MGQ_MpBattlesDuel
  CHALLENGE_COLOR = :challenge
  def self.available?; true; end
  def self.challenged_by?(peer); peer.state["challenge"] == "1"; end
  def self.accept(peer); $duel_answer = [:accept, peer.state["name"]]; end
  def self.decline(peer, reason); $duel_answer = [:decline, peer.state["name"], reason]; end

  # The challenges the notification box lists, as battles_duel.rbx offers them.
  module Offers
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
box = lambda { notices.instance_variable_get(:@box) }
shown = lambda { box.call && box.call.visible ? box.call.bitmap.texts : [] }
accept = lambda { $pressed = 0x59; notices.tick(true) }
decline = lambda { $pressed = 0x4E; notices.tick(true) }

# Nothing to tell.
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
check("with nothing to tell, no box", shown.call, [])

# An invite and a challenge from afar.
bea = { "id" => "bea", "name" => "Bea", "map" => 9, "x" => 1, "y" => 1, "d" => 2, "scene" => "map", "party" => "bea-p1", "invite" => 1, "invite_to" => "me" }
cid = { "id" => "cid", "name" => "Cid", "map" => 7, "x" => 1, "y" => 1, "d" => 2, "scene" => "map", "challenge" => 1, "challenge_to" => "me" }
$inbox << entry("in", 2) << entry("message", 2, told(bea)) << entry("in", 3) << entry("message", 3, told(cid))
MGQ_MpOverworldSync.tick
check("an invite and a challenge from afar show, the keys on the first", shown.call,
      ["Bea invites you to a party", "Y: Accept  N: Decline", "Cid challenges you to a duel"])
check("at the top left", [box.call.x, box.call.y], [8, 8])
4000.times { notices.tick(true) }
check("they stay as long as they stand", shown.call.first, "Bea invites you to a party")

# Messages show for a moment, below the invites, and take no key.
notices.message([:soon, 2], "Bea is in a battle!")
notices.tick(true)
check("a message shows below the invites, without a key", shown.call,
      ["Bea invites you to a party", "Y: Accept  N: Decline", "Cid challenges you to a duel", "Bea is in a battle!"])
MGQ_MpNotices::MESSAGE_FRAMES.times { notices.tick(true) }
check("and goes after a moment", shown.call.include?("Bea is in a battle!"), false)
notices.message(:alone, "A message alone")
notices.tick(true)
$inbox << entry("message", 2, told(bea.merge("invite" => 0))) << entry("message", 3, told(cid.merge("challenge" => 0)))
MGQ_MpOverworldSync.tick
$sounds.clear
accept.call
check("alone it shows without keys, and the key takes nothing", [shown.call, $sounds], [["A message alone"], []])
notices.drop(:alone)

# Declining.
$inbox << entry("message", 2, told(bea)) << entry("message", 3, told(cid))
MGQ_MpOverworldSync.tick
$sent.clear
decline.call
check("the decline key declines the first invite and tells the inviter", [$sent.map { |seat, text| [seat, text.include?("party_decline=1")] }, $sounds],
      [[[2, true]], ["cancel"]])
notices.tick(true)
check("which stays away while it stands", shown.call, ["Cid challenges you to a duel", "Y: Accept  N: Decline"])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2")))
MGQ_MpOverworldSync.tick
check("a new invite of the same player shows again", shown.call.first, "Bea invites you to a party")

# Accepting.
$sounds.clear
accept.call
check("the accept key accepts the first invite", [MGQ_MpCoop::Party.id, $sounds], ["bea-p2", ["ok"]])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2", "party_members" => "me", "invite" => 0)))
MGQ_MpOverworldSync.tick
check("then the challenge is first", shown.call, ["Cid challenges you to a duel", "Y: Accept  N: Decline"])

# A challenge in a menu.
SceneManager.scene = Scene_Item.new
accept.call
check("in a menu a challenge can only be declined", [shown.call, $duel_answer], [["Cid challenges you to a duel", "N: Decline"], nil])
decline.call
check("which tells the challenger", $duel_answer, [:decline, "Cid", "no"])
SceneManager.scene = Scene_Map.new
$inbox << entry("message", 3, told(cid.merge("challenge" => 0)))
MGQ_MpOverworldSync.tick
$inbox << entry("message", 3, told(cid))
MGQ_MpOverworldSync.tick

# Where the box hides.
$duel_answer = nil
SceneManager.scene = Scene_Battle.new
accept.call
check("hidden in a battle, where the keys take nothing", [shown.call, $duel_answer], [[], nil])
SceneManager.scene = Scene_Map.new
$overview_open = true
notices.tick(true)
check("hidden on the map while the World overview is open", shown.call, [])
$overview_open = false
$mgq_text_input = true
accept.call
check("the keys type instead while the player types", $duel_answer, nil)
$mgq_text_input = false
accept.call
check("otherwise the accept key accepts the challenge on the map", $duel_answer, [:accept, "Cid"])
$duel_answer = nil
accept.call
check("which then stays away while it stands, so another press accepts nothing", [shown.call.include?("Cid challenges you to a duel"), $duel_answer], [false, nil])

# Leaving the world.
notices.message(:left, "Gone with the world")
notices.tick(false)
notices.tick(true)
check("outside a world nothing shows, and the messages are gone", notices.notices.map(&:text).include?("Gone with the world"), false)

# A message shown outside a world, such as a Discord invite taken during a game.
$open = false
notices.message(:world_invite, "Discord invite taken")
notices.tick(false)
check("shows outside a world too, without the world's invites", shown.call, ["Discord invite taken"])
MGQ_MpNotices::MESSAGE_FRAMES.times { notices.tick(false) }
check("and goes after a moment", shown.call, [])
$open = true
