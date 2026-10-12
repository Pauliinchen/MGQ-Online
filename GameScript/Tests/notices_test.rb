#----------------------------------------------------------------
#  notices_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked that the box at its default lies 4 pixels below the Leader HUD
#                            - Checked that the accept key pressed while the player types stays out of the log, and that a refusal is logged under the hotkeys
#                            - Checked that the box at its default moves below the Leader HUD
#      Paulinchen  2026-10-11: Checked the box's place in the layout: its default below a strip at the top, a place the player left it in with its width and rows, its least size with the keys whole, and drawing anew after a preset change
#                            - Checked the box fading in and out, an answered invite and a message that runs out fading away, the last row saying how many more wait, a long notification cut to its row and the three spaces between what the keys do
#                            - Checked the keys drawn whole with a rebound key's longer name
#      Paulinchen  2026-10-08: Checked that an accepted invite shows again after a moment while it still stands, and a declined one stays away
#                            - Checked that an accepted invite stays away for the whole hold, and shows again at once when the inviter turns the accept down
#      Paulinchen  2026-10-07: Checked that an accepted invite stays away while it stands
#      Paulinchen  2026-10-06: Checked that a message shown outside a world shows there and goes after a moment
#      Paulinchen  2026-10-04: Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Offered the challenges through MGQ_MpActions, as the duel script does
#                            - Created
#
#----------------------------------------------------------------

# Covers the notification box, ui_notices.rbx: the invites it lists from anywhere in the world while
# they stand, the messages it shows for a moment, the scenes it shows in, its keys, its fades, the
# row that says how many more wait, and its place and size in the layout. Pictures measure each
# character at 7 pixels.

require_relative "world_support"

# Stand-ins for the game's pictures, which record the texts drawn whole and those drawn fading,
# where each text went and the fills, the colors, the World overview and duels.
class Color
  attr_reader :red, :green, :blue, :alpha
  def initialize(red = nil, green = nil, blue = nil, alpha = nil); @red, @green, @blue, @alpha = red, green, blue, alpha; end
end
class Bitmap
  Font = Struct.new(:outline, :size, :color, :bold, :out_color)
  attr_reader :texts, :fading, :font, :width, :height, :fills, :places
  def initialize(width = 1, height = 1); @width = width; @height = height; @texts = []; @fading = []; @fills = []; @places = []; @font = Font.new; end
  def clear; @texts = []; @fading = []; @fills = []; @places = []; end
  def fill_rect(x, y, width, height, color); @fills << [x, y, width, height, color]; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * 7, 16); end
  def draw_text(x, y, width, _height, text, _align = 0)
    color = font.color
    (color.is_a?(Color) && color.alpha && color.alpha < 255 ? @fading : @texts) << text
    @places << [text, x, y, width]
  end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :visible, :opacity
  def update; end
  def disposed?; false; end
  def dispose; end
end
module MGQ_MpWorldOverview; def self.open?; $overview_open; end; end
module MGQ_MpBattlesDuel
  CHALLENGE_COLOR = Color.new(255, 128, 128)
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
module MGQ_MpLeaderHud; def self.room; $leader_hud_room.to_i; end; end

load_script "ui_notices"

notices = MGQ_MpNotices
box = lambda { notices.instance_variable_get(:@box) }
showing = lambda { box.call && box.call.instance_variable_get(:@motion).shown? }
shown = lambda { showing.call ? box.call.bitmap.texts : [] }
fading = lambda { showing.call ? box.call.bitmap.fading : [] }
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
      ["Bea invites you to a party", "Y: Accept   N: Decline", "Cid challenges you to a duel"])
check("at the top left, fading in", [box.call.x, box.call.y, box.call.visible, box.call.opacity < 255], [8, 8, true, true])
(MGQ_MpUi::Style::FADE_FRAMES - 1).times { notices.tick(true) }
check("opaque after FADE_FRAMES", box.call.opacity, 255)
4000.times { notices.tick(true) }
check("they stay as long as they stand", shown.call.first, "Bea invites you to a party")

# A rebound key with a longer name widens the keys' column instead of cutting the keys.
MGQ_MpHotkeys.bind(:accept, 0x20)
MGQ_MpHotkeys.bind(:decline, 0x0D)
notices.tick(true)
check("the keys stay whole with a rebound key's longer name, given the room they need", shown.call[1], "key 32: Accept   key 13: Decline")
$player_ini.delete("key_accept")
$player_ini.delete("key_decline")
notices.tick(true)
check("and read the default keys again once they are back", shown.call[1], "Y: Accept   N: Decline")

# Messages show for a moment, below the invites, and take no key.
notices.message([:soon, 2], "Bea is in a battle!")
notices.tick(true)
check("a message shows below the invites, without a key", shown.call,
      ["Bea invites you to a party", "Y: Accept   N: Decline", "Cid challenges you to a duel", "Bea is in a battle!"])
MGQ_MpUi::Style::LINGER_FRAMES.times { notices.tick(true) }
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
check("which stays away while it stands", shown.call, ["Cid challenges you to a duel", "Y: Accept   N: Decline"])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2")))
MGQ_MpOverworldSync.tick
check("a new invite of the same player shows again", shown.call.first, "Bea invites you to a party")

# Accepting.
$sounds.clear
accept.call
check("the accept key accepts the first invite", [MGQ_MpCoop::Party.id, $sounds], ["bea-p2", ["ok"]])
check("which fades away below the others, taking no key", [fading.call.uniq, shown.call.first], [["Bea invites you to a party"], "Cid challenges you to a duel"])
MGQ_MpUi::Style::FADE_FRAMES.times { notices.tick(true) }
check("and is gone after FADE_FRAMES", fading.call, [])
$inbox << entry("message", 2, told(bea.merge("party" => "bea-p2", "party_members" => "me", "invite" => 0)))
MGQ_MpOverworldSync.tick
check("then the challenge is first", shown.call, ["Cid challenges you to a duel", "Y: Accept   N: Decline"])

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
refused = logged_lines { accept.call }
check("hidden in a battle, where the keys take nothing", [shown.call, $duel_answer], [[], nil])
check("which the log says under the hotkeys", refused.grep(/ignored/), ["keys: hotkey Y (Accept Notification) ignored: the box is hidden here"])
SceneManager.scene = Scene_Map.new
$overview_open = true
notices.tick(true)
check("hidden on the map while the World overview is open", shown.call, [])
$overview_open = false
$mgq_text_input = true
typed = logged_lines { accept.call }
check("the keys type instead while the player types, the letter left out of the log", [$duel_answer, typed.grep(/ignored/)], [nil, []])
$mgq_text_input = false
accept.call
check("otherwise the accept key accepts the challenge on the map", $duel_answer, [:accept, "Cid"])
$duel_answer = nil
accept.call
check("which then stays away for a moment, so another press accepts nothing", [shown.call.include?("Cid challenges you to a duel"), $duel_answer], [false, nil])
# The hold started with the accept a tick before the second press.
(MGQ_MpNotices::ACCEPT_HOLD_FRAMES - 2).times { notices.tick(true) }
check("for as long as a slow inviter may still show it", shown.call.include?("Cid challenges you to a duel"), false)
notices.tick(true)
check("and shows again while it still stands, since the accept did nothing", shown.call.include?("Cid challenges you to a duel"), true)
$duel_answer = nil
accept.call
notices.release([:duel, 3])
notices.tick(true)
check("or at once when the inviter turns the accept down", [shown.call.include?("Cid challenges you to a duel"), $duel_answer], [true, [:accept, "Cid"]])
$pressed = 0x4E
notices.tick(true)
MGQ_MpNotices::ACCEPT_HOLD_FRAMES.times { notices.tick(true) }
check("a declined invite stays away while it stands", shown.call.include?("Cid challenges you to a duel"), false)

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
MGQ_MpUi::Style::LINGER_FRAMES.times { notices.tick(false) }
check("and goes after a moment", shown.call, [])
$open = true

# A message fades over its last frames, then the box fades out, keeping its picture meanwhile.
$inbox << entry("message", 3, told(cid.merge("challenge" => 0)))
MGQ_MpOverworldSync.tick
MGQ_MpUi::Style::FADE_FRAMES.times { notices.tick(true) }
notices.message(:fading, "Going soon", MGQ_MpUi::Style::FADE_FRAMES + 1)
notices.tick(true)
check("a message with time left shows whole", [shown.call, fading.call], [["Going soon"], []])
notices.tick(true)
check("and fades over its last frames", [shown.call, fading.call], [[], ["Going soon"]])
MGQ_MpUi::Style::FADE_FRAMES.times { notices.tick(true) }
check("until it ran out, after which the box fades out with its picture kept", [showing.call, box.call.visible, box.call.opacity < 255, box.call.bitmap.fading], [false, true, true, ["Going soon"]])
(MGQ_MpUi::Style::FADE_FRAMES - 1).times { notices.tick(true) }
check("and is gone after FADE_FRAMES", [box.call.visible, box.call.opacity], [false, 0])

# More notifications than rows: the last row says how many more wait, and a long one is cut.
(1..7).each { |n| notices.message([:many, n], n == 7 ? "A message that goes on and on and on and on and on far past the box's width" : "Message #{n}") }
notices.tick(true)
check("past the box's rows the last row says how many more wait, the newest message first",
      [shown.call.size, shown.call.last, shown.call[1], shown.call.first.end_with?(MGQ_MpUi::ELLIPSIS)], [5, "+3 more", "Message 6", true])
check("the long message is cut to its row", box.call.bitmap.text_size(shown.call.first).width <= Sprite_MpNoticeBox::WIDTH - 2 * Sprite_MpNoticeBox::EDGE, true)
(1..7).each { |n| notices.drop([:many, n]) }
notices.tick(true)
check("dropped, they are gone at once", notices.notices, [])

# Where the box lies: its default, a place the player left it in, its least size and the preset.
layout = MGQ_MpUi::Layout
stored = layout.instance_variable_get(:@stored)
offered = lambda { offer = layout.instance_variable_get(:@offers).find { |each| each.id == :notices }; offer && offer.rect.to_a }
size = lambda { [box.call.bitmap.width, box.call.bitmap.height] }
many = lambda { |count| (1..count).each { |n| notices.message([:many, n], "Message #{n}") } }
drop_many = lambda { (1..12).each { |n| notices.drop([:many, n]) } }
registered = layout.instance_variable_get(:@boxes)[:notices]
check("the box is movable as Notifications, resizable both ways, never narrower than the keys beside a readable name nor lower than two rows",
      registered.to_a, ["Notifications", Sprite_MpNoticeBox::ACTION_WIDTH + Sprite_MpNoticeBox::MIN_TEXT_WIDTH + 2 * Sprite_MpNoticeBox::EDGE, 2 * Sprite_MpNoticeBox::ROW + 4, :both])
many.call(2)
notices.tick(true)
check("at its default it lies at the top left, WIDTH wide and MAX_ROWS high, offered to the layout where it lies",
      [box.call.x, box.call.y, size.call, offered.call], [8, 8, [390, 114], [8, 8, 390, 114]])
MGQ_MpUi.top_room = 30
notices.tick(true)
check("a strip at the top moves its default down", [box.call.y, offered.call[1]], [38, 38])
$leader_hud_room = 100
notices.tick(true)
check("and the Leader HUD at the top left moves it below itself", [box.call.y, offered.call[1]], [130, 130])
hud_margin, hud_below = 8, 4
hud_bottom = 30 + hud_margin + (100 - hud_margin - hud_below)
check("its top lies the HUD's gap of 4 pixels below the HUD's bottom", box.call.y - hud_bottom, hud_below)
$leader_hud_room = 0

$player_ini["ui_notices"] = "100,200,500,160"
stored.clear
drop_many.call
many.call(9)
notices.tick(true)
check("a place the player left it in holds whatever the strip, its picture as large", [box.call.x, box.call.y, size.call, offered.call], [100, 200, [500, 160], [100, 200, 500, 160]])
check("its height decides the rows, seven here, the last saying how many more wait", [shown.call.size, shown.call.first, shown.call.last], [7, "Message 9", "+3 more"])
wide = "A message too long for the box at its default width, whole when wider"
notices.message([:many, 10], wide)
notices.tick(true)
check("its width gives a long notification more room, whole here though the default would cut it",
      [box.call.bitmap.places.first[3], shown.call.first, box.call.bitmap.text_size(wide).width > Sprite_MpNoticeBox::WIDTH - 2 * Sprite_MpNoticeBox::EDGE], [500 - 2 * Sprite_MpNoticeBox::EDGE, wide, true])

$player_ini["ui_notices"] = "0,0,10,10"
stored.clear
$inbox << entry("message", 3, told(cid))
MGQ_MpOverworldSync.tick
places = box.call.bitmap.places
keys = places.find { |text, _, _, _| text == "Y: Accept   N: Decline" }
challenge = places.first
min_width = registered.min_width
check("made smaller than its least, it keeps its least size", [size.call, offered.call], [[min_width, 48], [0, 0, min_width, 48]])
check("where the keys stay whole at the right and the challenge, cut beside them, still names its sender",
      [keys.nil?, keys && keys[1] + keys[3], challenge[0].start_with?("Cid "), challenge[0].end_with?(MGQ_MpUi::ELLIPSIS), box.call.bitmap.text_size(challenge[0]).width <= challenge[3],
       keys && challenge[1] + challenge[3] <= keys[1]], [false, min_width - Sprite_MpNoticeBox::EDGE, true, true, true, true])
check("and its two rows show the challenge and how many more wait", [shown.call.size, shown.call.last], [3, "+10 more"])

MGQ_MpUi::Theme.apply("Monarch", "a test")
notices.tick(true)
check("a preset change draws the box anew, its frame with the preset's rim", box.call.bitmap.fills.size, 9)
MGQ_MpUi::Theme.apply("Legacy", "a test")
notices.tick(true)
check("and back without it", box.call.bitmap.fills.size, 5)
$player_ini.delete("ui_notices")
stored.clear
MGQ_MpUi.top_room = 0
drop_many.call
