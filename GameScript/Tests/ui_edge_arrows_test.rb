#----------------------------------------------------------------
#  ui_edge_arrows_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-11: Checked that a player outside the party gets a plain white arrow
#                            - Created
#
#----------------------------------------------------------------

# Covers the arrows at the screen's edge, ui_edge_arrows.rbx: which players get one (party
# members, everyone in a Raid World, the nearest eight), where an arrow sits on each side and in
# the corners and which way it points, the triangle's rows, the plate's clearance from the
# triangle, what hides every arrow, the sprites given out and taken back as players come and go,
# their fade in and out, and their log lines. Pictures measure each character at half the font's
# size.

require_relative "world_support"

$logs = []
module MGQ_Multiplayer; module Log; def self.write(m); $logs << m; puts "  log: #{m}"; end; end; end

# Stand-ins for the game's pictures.
Font = Struct.new(:size, :outline, :color, :bold, :out_color)
class Bitmap
  attr_reader :width, :height, :font, :texts, :fills, :outlines
  @@made = 0
  def self.made; @@made; end
  def initialize(width, height); @@made += 1; @width = width; @height = height; @font = Font.new(24); @texts = []; @fills = []; @outlines = 0; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  def draw_text(x, y, width, height, text, align = 0)
    return @outlines += 1 if @font.color.equal?(MGQ_MpUi::Style::OUTLINE)

    @texts << [x, y, width, text, align]
  end
  def fill_rect(*args)
    x, y, w, h, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, w, h, color]
  end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
class Sprite
  attr_accessor :bitmap, :x, :y, :z, :ox, :oy, :opacity, :visible, :viewport
  def initialize(viewport = nil); @viewport = viewport; @x = @y = @z = @ox = @oy = 0; @opacity = 255; @visible = true; end
  def update; end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end

# The map's view, from which a character's place on the screen follows.
class Game_Map; attr_accessor :display_x, :display_y; end
$game_map.display_x = $game_map.display_y = 0
class Game_Character
  def screen_x; (@x - $game_map.display_x) * 32 + 16; end
  def screen_y; (@y - $game_map.display_y) * 32 + 32; end
end
class Player
  def screen_x; (x - $game_map.display_x) * 32 + 16; end
  def screen_y; (y - $game_map.display_y) * 32 + 32; end
end
class Ghost < Game_Character; end

# The screens of the mod the arrows hide behind, which cover the action wheel as the real ones
# do, and the kind of world.
module MGQ_MpWorldOverview; def self.open?; $overview; end; end
module MGQ_MpEmotes; def self.open?; $emote_wheel; end; end
MGQ_MpActions.cover { |_wheel_key| MGQ_MpWorldOverview.open? }
MGQ_MpActions.cover { |_wheel_key| MGQ_MpEmotes.open? }
module MGQ_MpWorld; def self.raid?; $raid; end; end
$raid = false

load_script "ui_edge_arrows"

Arrows = MGQ_MpEdgeArrows
Style = MGQ_MpUi::Style

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

# Clears the players and the log.
def clear_world
  MGQ_MpOverworldSync::Peers.clear
  $logs.clear
end

# The player stands on tile 3, 4 with the map's view at its origin: the middle of their tile is at
# 112, 144 on the screen.

# Which players get an arrow.
member = arrive(2, "aa-member", "Member", 40, 4, true)
stranger = arrive(3, "bb-stranger", "Stranger", 3, 40)
near = arrive(4, "cc-near", "Near", 5, 4, true)
check("a party member off the screen gets an arrow, a stranger in a Classic world and a member on the screen none",
      Arrows.targets.map { |target| [target.id, target.screen_x, target.screen_y, target.tiles] }, [["aa-member", 1296, 144, 37]])
$raid = true
check("in a Raid World everyone off the screen gets one, nearest first", Arrows.targets.map { |target| [target.name, target.tiles] }, [["Stranger", 36], ["Member", 37]])
stranger.state["map"] = 6
check("a player on another map gets none", Arrows.targets.map(&:id), ["aa-member"])
stranger.state["map"] = 5
stranger.away = 100
check("nor one whose connection is down", Arrows.targets.map(&:id), ["aa-member"])
stranger.away = nil
member.ghost = nil
check("nor one without a ghost yet", Arrows.targets.map(&:id), ["bb-stranger"])
member.ghost = Ghost.new
member.ghost.moveto(40, 4)
member.state["hidden"] = 1
check("a player in a menu or a battle, whose ghost is transparent, keeps their arrow", Arrows.targets.map(&:id), ["bb-stranger", "aa-member"])
member.state.delete("hidden")
(10..19).each { |seat| arrive(seat, "dd-#{seat}", "Far #{seat}", 3 + seat, 40) }
check("at most eight arrows, the nearest, ties by id", Arrows.targets.map(&:tiles), [36, 37, 46, 47, 48, 49, 50, 51])
check("the near member is still none of them", Arrows.targets.map(&:id).include?("cc-near"), false)
check("why an arrow went: the player is on the screen, or others are nearer", [Arrows.gone_reason("cc-near"), Arrows.gone_reason("dd-19")], ["they are on the screen", "others are nearer"])
stranger.state["map"] = 6
check("or they left the map", Arrows.gone_reason("bb-stranger"), "they left the map")
stranger.state["map"] = 5
stranger.away = 100
check("or their connection is down, which comes before the map", Arrows.gone_reason("bb-stranger"), "their connection is down")
stranger.away = nil
$raid = false
check("in a Classic world the member alone", Arrows.targets.map(&:id), ["aa-member"])
check("and a stranger's arrow went since they are not in the party", Arrows.gone_reason("bb-stranger"), "they are not in the party")
check("or they left the world", Arrows.gone_reason("zz-nobody"), "they left the world")
clear_world

# Where an arrow sits: the line from the screen's middle crosses the edge rect, 14 pixels in.
check("the edge rect leaves the margin on each side", Arrows.edge_rect, [14, 14, 626, 466])
check("to the right: the right edge, level, pointing right", Arrows.point(320, 240, 900, 240), [626, 240, 0])
check("to the left: the left edge, pointing left", Arrows.point(320, 240, -100, 240), [14, 240, 180])
check("above: the top edge, pointing up", Arrows.point(320, 240, 320, -100), [320, 14, -90])
check("below: the bottom edge, pointing down", Arrows.point(320, 240, 320, 900), [320, 466, 90])
check("to the lower right: the corner, pointing between", Arrows.point(320, 240, 932, 692), [626, 466, 36])
check("to the upper left: the corner", Arrows.point(320, 240, -292, -212), [14, 14, -144])
check("to the upper right, nearer the top: the top edge", Arrows.point(320, 240, 420, -100), [386, 14, -74])
check("a line from inside the margin stays on the edge", Arrows.point(320, 5, 320, -100), [320, 14, -90])
check("a line that starts past the far edge, the player's sprite scrolled off, stays on the edge too", Arrows.point(700, 240, 900, 240), [626, 240, 0])
check("two equal points give no arrow", Arrows.point(320, 240, 320, 240), nil)
MGQ_MpUi.top_room = 40
check("a strip at the top moves the top edge down", Arrows.point(320, 240, 320, -100), [320, 54, -90])
MGQ_MpUi.top_room = 0
check("the angle is stepped to tens, halves away from zero", [36, 14, -144, 185, 0].map { |angle| Arrows.step_angle(angle) }, [40, 10, -140, 190, 0])

# The triangle's rows.
picture = Bitmap.new(20, 20)
Arrows.fill_triangle(picture, [[0.0, 0.0], [10.0, 0.0], [0.0, 10.0]], :fill)
check("a triangle is filled row by row, the whole base first, the tip last",
      [picture.fills.size, picture.fills.first, picture.fills.last], [11, [0, 0, 11, 1, :fill], [0, 10, 1, 1, :fill]])

# The plate's place: a 100 by 20 plate's nearest point clears the triangle's reach by the gap.
clear = Arrows::REACH + Arrows::LABEL_GAP
check("along an axis the plate's edge faces the triangle, its half past the gap",
      [Arrows.plate_distance(1.0, 0.0, 50.0, 10.0), Arrows.plate_distance(0.0, 1.0, 50.0, 10.0), Arrows.plate_distance(0.0, -1.0, 50.0, 10.0)], [clear + 50.0, clear + 10.0, clear + 10.0])
check("on a diagonal the plate's long edge faces it, nearer than the whole half width", Arrows.plate_distance(Math.cos(Math::PI / 4), Math.sin(Math::PI / 4), 50.0, 10.0).round(2), ((clear + 10.0) / Math.sin(Math::PI / 4)).round(2))
gaps = (0...360).step(Arrows::ANGLE_STEP).map do |angle|
  radians = angle * Math::PI / Arrows::HALF_TURN
  ux = Math.cos(radians)
  uy = Math.sin(radians)
  distance = Arrows.plate_distance(ux, uy, 50.0, 10.0)
  Math.sqrt([(ux * distance).abs - 50.0, 0].max ** 2 + [(uy * distance).abs - 10.0, 0].max ** 2).round(3)
end
check("at every stepped angle, a corner facing the triangle too, the nearest point keeps exactly the gap", gaps.uniq, [clear.to_f])

# What hides every arrow: every screen that covers the action wheel, through MGQ_MpActions.covered?.
covered = "a screen of the mod lies over the map"
check("nothing hides the arrows on a quiet map in a world", Arrows.hidden_reason, nil)
$open = false
check("outside a world", Arrows.hidden_reason, "no world is open")
$open = true
MGQ_MpActions::Wheel.instance_variable_set(:@open, true)
check("the action wheel", Arrows.hidden_reason, covered)
MGQ_MpActions::Wheel.instance_variable_set(:@open, false)
$emote_wheel = true
check("the emote wheel", Arrows.hidden_reason, covered)
$emote_wheel = false
$overview = true
check("the World overview", Arrows.hidden_reason, covered)
$overview = false
MGQ_MpChat.instance_variable_set(:@edit, Object.new)
check("the chat box", Arrows.hidden_reason, covered)
MGQ_MpChat.instance_variable_set(:@edit, nil)
$game_message.busy = true
check("a message", Arrows.hidden_reason, "a message shows")
$game_message.busy = false

# The sprites, through the map's hooks.
spriteset = Spriteset_Map.new
spriteset.update
pool = spriteset.instance_variable_get(:@mgq_mp_edge_arrows)
check("the map's update makes the pool, empty while nobody is off the screen", [pool.class, pool.arrows], [Arrows::Pool, []])
member = arrive(2, "aa-member", "Member", 40, 4, true)
spriteset.update
arrow = pool.arrows.first
check("a member off the screen gets a sprite at the right edge, sliding in from the edge, one step done",
      [pool.arrows.size, arrow.id, arrow.shown?, arrow.visible, arrow.z, [arrow.x, arrow.y]], [1, "aa-member", true, true, MGQ_MpUi::Z[:arrows], [635, 144]])
check("the arrows lie under the lines and the boxes of the map, which cover them", MGQ_MpUi::Z[:arrows] < MGQ_MpUi::Z[:lines], true)
check("the sprite's picture holds the plate with the name and the tiles", arrow.bitmap.texts.map { |text| text[3] }, ["Member 37"])
check("the plate lies left of the triangle, which points right", arrow.bitmap.fills.find { |fill| fill[4].equal?(Style::PLATE) }[0] + arrow.bitmap.fills.find { |fill| fill[4].equal?(Style::PLATE) }[2] < arrow.ox - Arrows::REACH, true)
check("the triangle is filled in the member's color over its outline",
      [arrow.bitmap.fills.count { |fill| fill[4].equal?(Style::OUTLINE) } > 0, arrow.bitmap.fills.count { |fill| fill[4].equal?(Style::MEMBER) }], [true, Arrows::WIDTH + 1])
check("the log says the arrow appeared, once", $logs.count { |line| line.include?("an arrow for Member (seat 2) appeared, 37 tiles away, in member") }, 1)
picture = arrow.bitmap
(Style::FADE_FRAMES - 1).times { spriteset.update }
check("after the fade the arrow is opaque at its place, drawn once", [arrow.opacity, [arrow.x, arrow.y], arrow.bitmap.equal?(picture)], [255, [626, 144], true])
check("and logged once", $logs.count { |line| line.include?("appeared") }, 1)

made = Bitmap.made
walk(member, 40, 40)
spriteset.update
check("a ghost that moves turns the arrow, now on the bottom edge, and draws it anew", [arrow.bitmap.equal?(picture), arrow.bitmap.texts.map { |text| text[3] }, [arrow.x, arrow.y]], [false, ["Member 73"], [443, 466]])
check("drawing anew makes the one picture, measuring on the sprite's own bitmap kept for it", Bitmap.made - made, 1)
check("its plate lies up and left of the triangle", [arrow.bitmap.fills.find { |fill| fill[4].equal?(Style::PLATE) }[1] + Arrows::LABEL_HEIGHT <= arrow.oy, arrow.bitmap.fills.find { |fill| fill[4].equal?(Style::PLATE) }[0] < arrow.ox], [true, true])
walk(member, 3, 40)
spriteset.update
check("a ghost straight below puts the plate above the triangle", arrow.bitmap.fills.find { |fill| fill[4].equal?(Style::PLATE) }[1] + Arrows::LABEL_HEIGHT <= arrow.oy - Arrows::REACH, true)

walk(member, 5, 4)
spriteset.update
check("a ghost that walks onto the screen fades its arrow out", [arrow.shown?, arrow.hidden?, pool.arrows.size], [false, false, 1])
check("the log says why it went", $logs.count { |line| line == "edge arrows: the arrow for Member (seat 2) is gone: they are on the screen" }, 1)
Style::FADE_FRAMES.times { spriteset.update }
check("once faded the sprite is invisible, kept for the next player", [arrow.hidden?, arrow.visible, arrow.opacity, arrow.disposed?], [true, false, 0, false])

$raid = true
stranger = arrive(3, "bb-stranger", "Long Name Player Seven", 3, 40)
spriteset.update
check("the next player takes the kept sprite, in plain white as a player outside the party",
      [pool.arrows.size, arrow.id, arrow.shown?, arrow.bitmap.fills.count { |fill| fill[4].equal?(MGQ_MpUi::PlayerColor.of(stranger)) }, MGQ_MpUi::PlayerColor.of(stranger).equal?(MGQ_MpUi::Style::TEXT), MGQ_MpUi::PlayerColor.label(stranger)],
      [1, "bb-stranger", true, Arrows::LENGTH + 1, true, "plain"])
check("a long name is cut to its width before the tiles", arrow.bitmap.texts.map { |text| text[3] }, ["Long Nam#{MGQ_MpUi::ELLIPSIS} 36"])
walk(member, 40, 4)
spriteset.update
check("a second player gets a second sprite", [pool.arrows.size, pool.arrows.map(&:id)], [2, ["bb-stranger", "aa-member"]])

MGQ_MpChat.instance_variable_set(:@edit, Object.new)
spriteset.update
check("the chat box fades every arrow out, logged once with why", [pool.arrows.map(&:shown?), $logs.count { |line| line == "edge arrows: arrows hidden: #{covered}" }], [[false, false], 1])
spriteset.update
check("and no arrow is logged as gone meanwhile", $logs.count { |line| line.include?("is gone") }, 1)
MGQ_MpChat.instance_variable_set(:@edit, nil)
spriteset.update
check("closing it shows them again, logged once", [pool.arrows.map(&:shown?), $logs.count { |line| line == "edge arrows: arrows shown again" }, $logs.count { |line| line.include?("appeared") }], [[true, true], 1, 3])

member.away = 100
spriteset.update
check("a member whose connection drops loses their arrow, logged with why", [pool.arrows.map(&:shown?), $logs.count { |line| line == "edge arrows: the arrow for Member (seat 2) is gone: their connection is down" }], [[true, false], 1])
member.away = nil
spriteset.update
check("back, they get it again", [pool.arrows.map(&:shown?), pool.arrows.size], [[true, true], 2])

(10..19).each { |seat| arrive(seat, "dd-#{seat}", "Far #{seat}", 3 + seat, 40) }
spriteset.update
check("ten more players off the screen make eight arrows in all", [pool.arrows.count(&:shown?), pool.arrows.size], [8, 8])
MGQ_MpOverworldSync::Peers.clear
spriteset.update
check("players who left the world fade every arrow out, each logged", [pool.arrows.count(&:shown?), $logs.count { |line| line.include?("is gone: they left the world") }], [0, 8])
(10..21).each { |seat| arrive(seat, "ee-#{seat}", "New #{seat}", 3 + seat, 40) }
spriteset.update
check("players arriving while the arrows fade out take the sprites furthest faded, up to the pool's limit", [pool.arrows.count(&:shown?), pool.arrows.size <= Arrows::Pool::LIMIT], [8, true])

appeared = $logs.count { |line| line.include?("appeared") }
spriteset.dispose
check("the map's dispose frees the sprites", [spriteset.instance_variable_get(:@mgq_mp_edge_arrows), pool.arrows], [nil, []])
check("and the pictures with them, the measuring one too", [arrow.disposed?, arrow.bitmap.disposed?, arrow.instance_variable_get(:@measure).disposed?], [true, true, true])
spriteset = Spriteset_Map.new
spriteset.update
pool = spriteset.instance_variable_get(:@mgq_mp_edge_arrows)
check("a new map starts with its own arrows, logged as appeared again", [pool.arrows.size, $logs.count { |line| line.include?("appeared") }], [8, appeared + 8])

arrive(5, "ff-nameless", "", 40, 4, true)
spriteset.update
nameless = pool.arrows.find { |candidate| candidate.id == "ff-nameless" }
check("a nameless member nearer than the eight takes an arrow, its plate reading the tiles alone", nameless.bitmap.texts.map { |text| text[3] }, [" 37"])
check("and the furthest of the eight gives way, logged with why", $logs.count { |line| line == "edge arrows: the arrow for New 17 (seat 17) is gone: others are nearer" }, 1)

# A failing frame is logged once, fades every arrow out and the map goes on.
Style::FADE_FRAMES.times { spriteset.update }
MGQ_MpOverworldSync::Peers.all.first.ghost = Object.new
2.times { spriteset.update }
check("a frame that fails is logged once", $logs.count { |line| line.start_with?("edge arrows: the arrows failed: NoMethodError") }, 1)
check("and fades the arrows out, so none stays frozen", [pool.arrows.any?(&:shown?), pool.arrows.all?(&:hidden?)], [false, false])
(Style::FADE_FRAMES - 2).times { spriteset.update }
check("every arrow is gone once the fault lasted a fade", pool.arrows.all?(&:hidden?), true)
