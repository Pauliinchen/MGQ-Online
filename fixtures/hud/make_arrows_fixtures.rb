#----------------------------------------------------------------
#  make_arrows_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Writes the golden cases of the edge arrows next to this file, arrows.json, from
# ui_edge_arrows.rbx as it kept their rules before they moved to C# (MGQOnline.Game's
# Hud/EdgeArrows): where an arrow sits and points for lines from the player to another player, the
# angle stepped, the picture of an arrow with its plate, triangle and slide, and frames of players
# coming, going and hidden with the players pointed at and the lines logged. MGQOnline.Game.Tests
# replays them.
#
# It runs on the scripts of commit 2f6888c0, which still kept the rules in ui_edge_arrows.rbx,
# through the script tests' stand-ins, on Ruby 3.3, from a checkout of that commit with this file
# copied in:
#
#   ruby fixtures/hud/make_arrows_fixtures.rb

require "json"
require_relative "../../GameScript/Tests/world_support"

# The log's lines, which the frames record when they are the arrows'.
$logs = []
module MGQ_Multiplayer::Log; def self.write(line); $logs << line; end; end

load_script "ui_edge_arrows"
ARROWS = MGQ_MpEdgeArrows

# A picture that records its size and the rows filled, each [x, y, width, color].
class Bitmap
  attr_reader :width, :height, :rows
  def initialize(width = 0, height = 0); @width = width; @height = height; @rows = []; end
  def fill_rect(x, y, width, _height, color); @rows << [x, y, width, color]; end
  def dispose; end
  def disposed?; false; end
end

# What measures a plate's text: as wide as the plate less its padding.
Measure = Struct.new(:width) { def text_size(_text); Rect.new(0, 0, width, 16); end }

# The style draws nothing but notes where the plate goes.
module MGQ_MpUi::Style
  def self.use_font(*); end
  def self.draw_plated(_bitmap, x, y, _width, _height, _text); $plated = [x, y]; end
end
def MGQ_MpUi.cut(_measure, text, _width); text; end

# A ghost on the player's map: where it shows and how far it stands.
Ghost = Struct.new(:screen_x, :screen_y, :tiles) do
  def distance_x_from(_x); tiles; end
  def distance_y_from(_y); 0; end
end

# The other players a frame shows, by seat, and whether the world is a Raid World.
$players = []
$raid = false
module MGQ_MpOverworldSync::Peers
  def self.all; $players; end
  def self.on_this_map?(peer); peer.away.nil? && peer.state["map"].to_i == 5; end
end
module MGQ_MpCoop::Scope; def self.raid?; $raid; end; end
module MGQ_MpUi::PlayerColor; def self.label(peer); peer.state["color"]; end; end

# Where lines from the player's sprite meet the edge, with the strip at the top or none.
POINTS = [[320, 224, 900, 224], [320, 224, -300, 224], [320, 224, 320, -50], [320, 224, 320, 800], [320, 224, 1000, 900],
          [320, 224, -100, -380], [320, 224, 700, -10], [320, 224, 321, 900], [320, 224, 320, 224], [10, 470, -5, 470],
          [320, 224, 333, 1000], [320, 224, -777, 223]]
points = [0, 40].flat_map do |top|
  MGQ_MpUi.top_room = top
  POINTS.map { |from_x, from_y, to_x, to_y| { "top_room" => top, "line" => [from_x, from_y, to_x, to_y], "point" => ARROWS.point(from_x, from_y, to_x, to_y) } }
end
MGQ_MpUi.top_room = 0

# Every angle stepped.
steps = (-180..180).map { |angle| [angle, ARROWS.step_angle(angle)] }

# The picture of an arrow for every stepped angle and a few plates' widths, as the sprite draws it.
class Sprite_MpEdgeArrow
  attr_accessor :bitmap, :ox, :oy
end
Plated = Struct.new(:name, :tiles)
plates = (-180..180).step(10).flat_map do |angle|
  [44, 75, 131].map do |width|
    sprite = Sprite_MpEdgeArrow.allocate
    sprite.instance_variable_set(:@measure, Measure.new(width - 2 * MGQ_MpUi::Style::PAD))
    sprite.draw(Plated.new("Name", 3), angle, :fill)
    radians = angle * Math::PI / ARROWS::HALF_TURN
    { "angle" => angle, "width" => width,
      "picture" => [-sprite.ox, -sprite.oy, sprite.bitmap.width, sprite.bitmap.height],
      "plate" => $plated,
      "slide" => [(Math.cos(radians) * ARROWS::SLIDE_PIXELS).round, (Math.sin(radians) * ARROWS::SLIDE_PIXELS).round],
      "rows" => sprite.bitmap.rows.map { |x, y, w, color| [x, y, w, color == :fill ? 1 : 0] } }
  end
end

# Makes another player.
#
# @param seat [Integer] Their seat.
# @param id [String] Their id.
# @param fields [Hash] "x", "y" of their ghost on the screen and "tiles", or "away", "map",
#   "member", "color", "ghost" (false for none).
# @return [MGQ_MpOverworldSync::Peers::Peer] The player.
def player(seat, id, fields)
  state = { "id" => id, "name" => id.capitalize, "map" => fields["map"] || 5, "color" => fields["color"] || "white" }
  ghost = fields["ghost"] == false ? nil : Ghost.new(fields["x"], fields["y"], fields["tiles"])
  MGQ_MpOverworldSync::Peers::Peer.new(seat, state, ghost, fields["member"] ? true : false, fields["away"] ? true : nil)
end

# The frames, each the players, whether the world is a Raid World and why the arrows hide.
FRAMES = [
  { "raid" => false, "players" => [[2, "anna", { "x" => 900, "y" => 100, "tiles" => 30, "member" => true, "color" => "green" }],
                                   [3, "bert", { "x" => -50, "y" => 300, "tiles" => 12 }],
                                   [4, "carl", { "x" => 100, "y" => 100, "tiles" => 2, "member" => true }]] },
  { "raid" => true, "players" => [[2, "anna", { "x" => 900, "y" => 100, "tiles" => 30, "member" => true, "color" => "green" }],
                                  [3, "bert", { "x" => -50, "y" => 300, "tiles" => 12 }],
                                  [4, "carl", { "x" => 100, "y" => 100, "tiles" => 2, "member" => true }]] },
  { "raid" => true, "players" => (1..10).map { |n| [10 + n, "p#{format('%02d', 11 - n)}", { "x" => -20 * n, "y" => 600, "tiles" => n < 6 ? 9 : 20 + n }] } },
  { "raid" => true, "reason" => "a message shows", "players" => [[11, "p10", { "x" => -20, "y" => 600, "tiles" => 9 }]] },
  { "raid" => true, "players" => [[11, "p10", { "x" => -20, "y" => 600, "tiles" => 9 }], [12, "p09", { "x" => -40, "y" => 600, "tiles" => 9 }],
                                  [13, "p08", { "away" => true, "x" => -60, "y" => 600, "tiles" => 9 }], [14, "p07", { "map" => 6, "ghost" => false }],
                                  [15, "p06", { "x" => 300, "y" => 200, "tiles" => 4 }]] },
  { "raid" => false, "players" => [[11, "p10", { "x" => -20, "y" => 600, "tiles" => 9 }], [12, "p09", { "x" => -40, "y" => 600, "tiles" => 9, "member" => true }]] },
  { "raid" => false, "players" => [] },
]
frames = FRAMES.map do |frame|
  $logs.clear
  $raid = frame["raid"]
  $players = frame["players"].map { |seat, id, fields| player(seat, id, fields) }
  reason = frame["reason"]
  targets = reason ? [] : ARROWS.targets
  ARROWS.note(reason, targets)
  frame.merge("targets" => targets.map { |target| [target.peer.seat, target.screen_x, target.screen_y, target.tiles] }, "logs" => $logs.dup)
end

File.write(File.join(__dir__, "arrows.json"), JSON.pretty_generate({ "points" => points, "steps" => steps, "plates" => plates, "frames" => frames }) + "\n")
puts "wrote #{points.size} points, #{plates.size} plates and #{frames.size} frames"
