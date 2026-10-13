#----------------------------------------------------------------
#  ui_party_box_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked the size hotkey pressed while the player types
#                            - Stood in for the parts of the world's story
#      Paulinchen  2026-10-11: Called the small box with the party and the others apart
#                            - Checked the box's place in the layout
#                            - Checked that a stranger is named in plain white
#                            - Created
#
#----------------------------------------------------------------

# Covers the party box and the map box, ui_party_box.rbx: their columns, icons and colors, long
# names, away members, the small box, the log of who is listed, the size hotkey while the player
# types, fading on the map, and the box's place and width in the layout.

require_relative "world_support"

# A text drawn on a picture: what, where, how wide, in which color and size, aligned how.
Text = Struct.new(:text, :x, :width, :color, :size, :align) do
  # Tells where the text's room ends.
  def right; x + width; end
end

# Stands in for the game's picture, recording the texts, fills and icons drawn on it, each
# character 8 pixels wide.
class Bitmap
  # The picture's font.
  Font = Struct.new(:size, :color, :bold, :outline, :out_color)
  attr_reader :texts, :fills, :icons, :font, :width, :height
  # Makes an empty picture.
  def initialize(width = 1, height = 1); @width = width; @height = height; @texts = []; @fills = []; @icons = []; @font = Font.new; end
  # Answers whether the picture was disposed.
  def disposed?; @disposed ? true : false; end
  # Forgets everything drawn.
  def clear; @texts.clear; @fills.clear; @icons.clear; end
  # Records a fill.
  def fill_rect(x, y, width, height, color); @fills << [x, y, width, height, color]; end
  # Measures a text at 8 pixels a character and 16 high.
  def text_size(text); Rect.new(0, 0, text.to_s.size * 8, 16); end
  # Records a text in the font's color and size.
  def draw_text(x, _y, width, _height, text, align = 0); @texts << Text.new(text, x, width, font.color, font.size, align); end
  # Records an icon by its index on the icon set, with where it lands and how wide.
  def stretch_blt(dest, _set, rect, *_); @icons << [rect.y / MGQ_MpUi::ICON_SIZE * MGQ_MpUi::ICONS_PER_ROW + rect.x / MGQ_MpUi::ICON_SIZE, dest.x, dest.width]; end
  # Disposes of the picture.
  def dispose; @disposed = true; end
end
# Gives the sprite stand-in what the box sets and calls.
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :visible, :opacity
  # Stands in for the sprite's update, which does nothing here.
  def update; end
  # Stands in for disposing of the sprite, which does nothing here.
  def dispose; end
  # Answers that the sprite is never disposed.
  def disposed?; false; end
end
# Stands in for the game's cache, whose every system picture is the icon set.
module Cache; def self.system(_name); :iconset; end; end
# Reopens the stand-ins of Multiplayer.rb.
module MGQ_Multiplayer
  # Stands in for the mouse, resting at the top left, never clicked.
  module Mouse
    # Answers the top left.
    def self.position; [0, 0]; end
    # Answers that the mouse is never clicked.
    def self.clicked?; false; end
  end
end
# Stands in for the world, named Test World and a Raid World while $raid is set.
module MGQ_MpWorld
  # Answers the world, named Test World.
  def self.world; Struct.new(:name).new("Test World"); end
  # Answers whether the world is a Raid World, as $raid says.
  def self.raid?; $raid; end
end
# Stands in for the world's story, which the overview reads the parts' starts from.
module MGQ_MpWorldStory
  # The story progress Part 2 starts at.
  PART_TWO = 19
  # The story progress Part 3 starts at.
  PART_THREE = 34
end
# Stands in for duels, which offer nothing.
module MGQ_MpBattlesDuel
  # Answers that no duel is offered with a player.
  def self.peer_option(_peer); nil; end
  # Answers that no duel is offered on the player's own row.
  def self.own_options; []; end
  # Answers that no other player challenges the player.
  def self.call_of(_peer); nil; end
end
load_script "world_overview"
# Stands in for the emote wheel, which stays shut.
module MGQ_MpEmotes; def self.open?; false; end; end
load_script "ui_party_box"

style = MGQ_MpUi::Style
box_class = Sprite_MpPartyBox
columns = box_class::COLUMNS
long_name = "A Very Long Player Name Indeed"

# Two other players join the world: the party's leader, in a battle, and a stranger who types.
$inbox << entry("seat", 0)
MGQ_MpOverworldSync.tick
leader_state = { "id" => "leader", "name" => long_name, "map" => 5, "x" => 1, "y" => 1, "d" => 2, "scene" => "battle", "ping" => 999 }
stranger_state = { "id" => "stranger", "name" => "Stranger", "map" => 5, "x" => 2, "y" => 2, "d" => 2, "scene" => "typing", "ping" => 80 }
$inbox << entry("in", 2) << entry("message", 2, told(leader_state)) << entry("in", 3) << entry("message", 3, told(stranger_state))
MGQ_MpOverworldSync.tick
leader = MGQ_MpOverworldSync::Peers.at(2)
stranger = MGQ_MpOverworldSync::Peers.at(3)
row = MGQ_MpWorldOverview::Row
# Tells a ping as the overview labels it.
ping = lambda { |milliseconds| MGQ_MpOverworld.ping_label(milliseconds) }
own_row = row.new(:me, "Me", "Castle", "Lv 55", "", ping.call(40), nil, true, ["2 / 4", false], nil)
leader_row = row.new(leader, long_name, "Forest", "Lv 100", "", ping.call(999), MGQ_MpOverworld::STATE_ICONS["battle"], true, ["2 / 4", true], nil)
stranger_row = row.new(stranger, "Stranger", "", "Lv 20", "", ping.call(80), MGQ_MpOverworld::TYPING_ICON, false, nil, nil)
party = [leader_row, own_row]

box = box_class.new(nil)
# Finds a text drawn on the box.
text = lambda { |label| box.bitmap.texts.find { |drawn| drawn.text == label } }
# Tells every text drawn on the box.
texts = lambda { box.bitmap.texts.map(&:text) }
# Finds a name drawn on the full box, cut to its column.
named = lambda { |name| text.call(MGQ_MpUi.cut(box.bitmap, name, box.name_width(box_class::WIDTH, true))) }

# In the full box the name, the level and the ping never meet, and both "Lv 100" and "999 ms" fit
# their columns.
box.draw(party)
level = text.call("Lv 100")
ping_text = text.call("999 ms")
name = named.call(long_name)
check("the box's left lies at the top right, where its motion places it, as wide as its columns", [box.instance_variable_get(:@left), box.bitmap.fills.first[2]], [640 - box_class::WIDTH - box_class::MARGIN, box_class::WIDTH])
check("the name ends before the level, the level before the ping", [name.right <= level.x, level.right <= ping_text.x], [true, true])
check("Lv 100 fits the level column, 999 ms the ping column, right-aligned", [level.width >= box.bitmap.text_size("Lv 100").width, ping_text.width >= box.bitmap.text_size("999 ms").width, ping_text.align], [true, true, 2])
check("the ping column ends at the box's edge", ping_text.right, box_class::WIDTH - box_class::EDGE)

# The icon of what a player does stands before their name, after the leader's crown.
icons = box.bitmap.icons
check("the leader's crown and battle icon stand before the name, the player's own line has none",
      [icons.map(&:first), icons.map { |_, x, _| x }, icons.all? { |_, x, _| x < columns[:name] }],
      [[MGQ_MpOverworld::CROWN_ICON, MGQ_MpOverworld::STATE_ICONS["battle"]], [columns[:crown], columns[:icon]], true])
check("the icons fit a line", icons.map(&:last).uniq, [box_class::ICON_SIDE])

# The colors of the lines, the pings, the titles and the places.
check("the player's own line is in the own color, the member's green, the level plain",
      [text.call("Me").color.equal?(style::OWN), name.color.equal?(style::MEMBER), level.color.equal?(style::TEXT)], [true, true, true])
check("a ping keeps its color", [ping_text.color.equal?(MGQ_MpOverworld::PING_COLORS.last[1]), text.call("40 ms").color.equal?(MGQ_MpOverworld::PING_COLORS.first[1])], [true, true])
check("the titles are in the small font, the party's green", [texts.call.first, text.call("Party").size, text.call("Party").color.equal?(style::MEMBER)], ["Party", style::SMALL_SIZE, true])
size_hint = text.call("Tab: size")
check("the title line names the hotkey that changes the size at its right, dim, with the title cut before it",
      [size_hint.nil?, size_hint && size_hint.align, size_hint && size_hint.color.equal?(style::DIM), text.call("Party").width <= box_class::WIDTH - 2 * box_class::EDGE - box.bitmap.text_size("Tab: size").width],
      [false, 2, true, true])
check("the name column holds 14 letters of the small font", box.name_width(box_class::WIDTH, true) >= box.bitmap.text_size("A" * 14).width, true)
box.draw([row.new(leader, "Laggy", "Forest", "Lv 100", "", ping.call(1234), nil, true, nil, nil)])
slow_ping = text.call("999+ ms")
check("a ping past 999 ms shows as 999+ ms, which the ping column fits", [slow_ping.nil?, slow_ping && box.bitmap.text_size(slow_ping.text).width <= MGQ_MpOverworld::PING_WIDTH], [false, true])
MGQ_MpUi.draw_icon(box.bitmap, nil, 0, 0)
check("no icon draws nothing", box.bitmap.icons, [])
box.draw(party)
check("the places are small headings", text.call("Forest").size == style::TINY_SIZE && text.call("Forest").color.equal?(style::HEADING), true)

# A long name is cut to its column.
check("a long name is cut to the name column with an ellipsis", [name.text.end_with?(MGQ_MpUi::ELLIPSIS), name.text.size < long_name.size, box.bitmap.text_size(name.text).width <= name.width], [true, true, true])
check("a short name stays whole", text.call("Me").text, "Me")

# A member whose connection is down is dim, with the away icon.
leader.away = 60
box.draw(party)
away_name = named.call(long_name)
check("an away member is dim, with the away icon in place of the battle's", [away_name.color.equal?(style::DIM), box.bitmap.icons.map(&:first)], [true, [MGQ_MpOverworld::CROWN_ICON, MGQ_MpPartyBox::AWAY_ICON]])
check("the player's own line is never away", [MGQ_MpPartyBox.away?(own_row), MGQ_MpPartyBox.away?(leader_row)], [false, true])
leader.away = nil

# The map box of a Raid World names a stranger in plain white.
map_rows = [own_row, leader_row, stranger_row]
box.draw_map(map_rows)
stranger_name = text.call("Stranger")
check("the map box is titled with how many are on the map, the size hint at the right too", [texts.call.first, texts.call.include?("Tab: size")], ["Map 3", true])
check("a stranger is named in plain white, which the keyboard of their typing precedes",
      [stranger_name.color.equal?(MGQ_MpUi::PlayerColor.of(stranger)), stranger_name.color.equal?(style::TEXT), box.bitmap.icons.map(&:first).include?(MGQ_MpOverworld::TYPING_ICON)],
      [true, true, true])
check("the member stays green and the player's own line yellow", [named.call(long_name).color.equal?(style::MEMBER), text.call("Me").color.equal?(style::OWN)], [true, true])

# The small box shows no level, the icon still before the name and the ping at the edge.
box.draw_small([], map_rows)
small_name = text.call(MGQ_MpUi.cut(box.bitmap, long_name, box.name_width(box_class::SMALL_WIDTH, false)))
small_ping = text.call("999 ms")
check("small, the box is narrower and shows no level", [box.instance_variable_get(:@left), box.bitmap.fills.first[2], texts.call.include?("Lv 100")], [640 - box_class::SMALL_WIDTH - box_class::MARGIN, box_class::SMALL_WIDTH, false])
check("the name is cut to what lies before the ping, which ends at the edge", [small_name.nil?, small_name && small_name.right <= small_ping.x, small_ping.right], [false, true, box_class::SMALL_WIDTH - box_class::EDGE])
check("the icons stand before the names in the small box too", box.bitmap.icons.map(&:first), [MGQ_MpOverworld::CROWN_ICON, MGQ_MpOverworld::STATE_ICONS["battle"], MGQ_MpOverworld::TYPING_ICON])

# The log names who the box lists, with each player's color and whether they are away.
logged = []
writer = MGQ_Multiplayer::Log.method(:write)
MGQ_Multiplayer::Log.define_singleton_method(:write) { |line| logged << line }
MGQ_MpPartyBox.note_rows(party)
MGQ_MpPartyBox.note_rows(party)
leader.away = 60
MGQ_MpPartyBox.note_rows(party)
leader.away = nil
MGQ_MpPartyBox.note_rows(map_rows, true)
MGQ_MpPartyBox.note_rows([])
MGQ_Multiplayer::Log.define_singleton_method(:write, writer)
check("the log names each listed player's color and whether they lead or are away, once per change", logged,
      ["party box: party box lists #{long_name} (leader, member), Me (own)",
       "party box: party box lists #{long_name} (leader, dim, away), Me (own)",
       "party box: map box lists Me (own), #{long_name} (leader, member), Stranger (#{MGQ_MpUi::PlayerColor.label(stranger)})",
       "party box: party box hidden"])

# The size hotkey does nothing while the player types.
small_before = MGQ_MpPartyBox.small?
MGQ_MpChat.start_typing
$mgq_text_input = true
$pressed = MGQ_MpHotkeys.code(:party_box)
typed = logged_lines { MGQ_MpPartyBox.on_map }
$mgq_text_input = nil
MGQ_MpChat.stop_typing
check("Tab typed into the chat box changes nothing and stays out of the log", [MGQ_MpPartyBox.small?, typed.grep(/ignored/)], [small_before, []])

# On the map the box fades in, is drawn anew when a member goes away and comes back, and fades out
# outside a party.
MGQ_MpWorldOverview.define_singleton_method(:open?) { false }
MGQ_MpWorldOverview.define_singleton_method(:party_rows) { party }
box.update
check("on the map the box shows the party, titled by the player's own party badge, which none is here, fading in", [box.visible, box.opacity < 255, texts.call.first], [true, true, "Party"])
(style::FADE_FRAMES - 1).times { box.update }
check("opaque after FADE_FRAMES, at the top right", [box.opacity, box.x, box.y], [255, 640 - box_class::WIDTH - box_class::MARGIN, box_class::MARGIN])
leader.away = 60
box_class::READ_FRAMES.times { box.update }
check("a member gone away is drawn dim once the box reads the party again", named.call(long_name).color.equal?(style::DIM), true)
leader.away = nil
box_class::READ_FRAMES.times { box.update }
check("and green again once they are back", named.call(long_name).color.equal?(style::MEMBER), true)
MGQ_MpWorldOverview.define_singleton_method(:party_rows) { [] }
motion = box.instance_variable_get(:@motion)
box_class::READ_FRAMES.times { box.update; break unless motion.shown? }
check("outside a party the box fades out once it reads the party again, its picture kept meanwhile", [box.visible, box.opacity < 255, texts.call.first], [true, true, "Party"])
(style::FADE_FRAMES - 1).times { box.update }
check("until it is gone", [box.visible, box.opacity], [false, 0])

# Where the box lies and how wide: its default, a place the player left it in, its least width,
# the small size and the presets.
layout = MGQ_MpUi::Layout
stored = layout.instance_variable_get(:@stored)
# Tells where the box offers itself to the layout, nil while it offers nothing.
offered = lambda { offer = layout.instance_variable_get(:@offers).find { |each| each.id == :party_box }; offer && offer.rect.to_a }
# Updates the box until it reads the party again.
read = lambda { box_class::READ_FRAMES.times { box.update } }
width = box_class::WIDTH
edge = box_class::EDGE
check("the box is movable as Party box, widened only, never narrower than its columns nor lower than a line",
      layout.instance_variable_get(:@boxes)[:party_box].to_a, ["Party box", width, box_class::ROW + 4, :width])
MGQ_MpWorldOverview.define_singleton_method(:party_rows) { party }
read.call
party_height = box_class::ROW + box_class::PLAYER_ROW * 2 + 4
check("at its default it lies at the top right, as tall as the party, offered to the layout where it lies",
      [box.x, box.y, offered.call], [640 - width - box_class::MARGIN, 8, [640 - width - box_class::MARGIN, 8, width, party_height]])
MGQ_MpUi.top_room = 30
box.update
check("a strip at the top moves its default down", [box.y, offered.call[1]], [38, 38])

$player_ini["ui_party_box"] = "100,50,400,10"
stored.clear
box.update
level = text.call("Lv 100")
ping_text = text.call("999 ms")
name = text.call(MGQ_MpUi.cut(box.bitmap, long_name, box.name_width(400, true)))
check("a place the player left it in holds whatever the strip, as wide as it was left, as tall as the party",
      [box.x, box.y, offered.call, box.bitmap.width, box.bitmap.fills.first[2]], [100, 50, [100, 50, 400, party_height], 400, 400])
check("the extra width goes to the names and the places, the level staying beside the ping at the right edge",
      [name.nil?, name && name.width - box.name_width(width, true), level.x, ping_text.right, text.call("Forest").width], [false, 400 - width, columns[:level] + 400 - width, 400 - edge, 400 - columns[:name] - edge])
box.draw_map(map_rows)
check("the map box takes the width too", [box.bitmap.fills.first[2], text.call("Lv 20").x, text.call("80 ms").right], [400, columns[:level] + 400 - width, 400 - edge])

$player_ini["ui_party_box"] = "300,50,100,10"
stored.clear
box.update
level = text.call("Lv 100")
ping_text = text.call("999 ms")
name = named.call(long_name)
check("made narrower than its least, it keeps its columns' width, where the name, the level and the ping still never meet",
      [offered.call[2], name.right <= level.x, level.right <= ping_text.x, ping_text.right], [width, true, true, width - edge])

$player_ini["ui_party_box"] = "100,50,400,10"
stored.clear
MGQ_MpPartyBox.instance_variable_set(:@small, true)
box.update
check("small, it keeps its own width at the right edge of the box's place, which the layout still takes whole",
      [box.x, box.bitmap.fills.first[2], offered.call], [100 + 400 - box_class::SMALL_WIDTH, box_class::SMALL_WIDTH, [100, 50, 400, box_class::ROW * 2 + 4]])
MGQ_MpPartyBox.instance_variable_set(:@small, false)

MGQ_MpUi::Theme.apply("Monarch", "a test")
read.call
check("a preset change draws the box anew once it reads the party, its frame with the preset's rim", box.bitmap.fills.size, 9)
MGQ_MpUi::Theme.apply("Legacy", "a test")
read.call
check("and back without it", box.bitmap.fills.size, 5)
$player_ini.delete("ui_party_box")
stored.clear
MGQ_MpUi.top_room = 0
