#----------------------------------------------------------------
#  ui_edge_arrows.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Arrows at the screen's edge toward the players on the map whose ghost is off the screen: a small
# filled triangle in the player's color where the line from the player's sprite to them crosses
# the edge, with their name and how many tiles away they are on a plate inside the screen. Party
# members get one always, everyone else only in a Raid World, the nearest MAX_ARROWS at most. A
# player in a menu or a battle, whose ghost is drawn transparent, keeps their arrow: it is them the
# others look for. The arrows hide while a wheel, the World overview or the chat box is open, while
# a message shows, and outside a world, fading in and out.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpEdgeArrows
  # Most arrows at once: the nearest players.
  MAX_ARROWS = 8

  # Pixels between the screen's edge and an arrow's center, room for the triangle's reach.
  MARGIN = 14

  # Pixels from a triangle's base to its tip, and across its base.
  LENGTH = 14
  WIDTH = 12

  # Pixels the triangle reaches from its center at most: half its diagonal, see Sprite_MpEdgeArrow.
  REACH = Math.sqrt((LENGTH / 2.0) ** 2 + (WIDTH / 2.0) ** 2).ceil

  # Degrees an arrow turns by at least before it is drawn anew, so a ghost walking in the distance
  # does not redraw it every frame.
  ANGLE_STEP = 10

  # Pixels a player's name may take on the plate before it is cut.
  NAME_WIDTH = 90

  # Height of the plate with the name and the tiles.
  LABEL_HEIGHT = 20

  # Pixels between the triangle and its plate.
  LABEL_GAP = 4

  # How the plate reads: the name, then the tiles away.
  LABEL = "%s %d"

  # Pixels an arrow slides in from, toward the edge, as it fades in.
  SLIDE_PIXELS = 10

  # Pixels from a ghost's screen_y, the bottom of its tile, up to the tile's middle.
  HALF_TILE = 16

  # Degrees in a half turn, for Math.atan2's radians.
  HALF_TURN = 180

  # A player an arrow points at: their peer, where their ghost is on the screen and how far away
  # they stand.
  #
  # @!attribute peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  # @!attribute screen_x [Integer] The middle of their ghost's tile on the screen, x.
  # @!attribute screen_y [Integer] The middle of their ghost's tile on the screen, y.
  # @!attribute tiles [Integer] The tiles to walk to them, the map's loop taken into account.
  Target = Struct.new(:peer, :screen_x, :screen_y, :tiles) do
    # The player's id, which tells their arrow from the others.
    #
    # @return [String] The id.
    def id
      peer.state["id"].to_s
    end

    # The name their arrow shows: the one above their ghost's head.
    #
    # @return [String] The name.
    def name
      MGQ_MpOverworld.name_tag(peer)
    end
  end

  @shown = {}
  @reason = nil

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "edge arrows"

  # Tells why no arrow shows now.
  #
  # @return [String, nil] The reason, nil while the arrows may show.
  def self.hidden_reason
    return "no world is open" unless MGQ_MpOverworldSync.in_world?
    return "a screen of the mod lies over the map" if MGQ_MpActions.covered?
    return "a message shows" if $game_message && $game_message.busy?

    nil
  end

  # Finds the players to point at: on the player's map with their ghost off the screen, party
  # members and in a Raid World everyone, the nearest MAX_ARROWS by tiles, ties by id.
  #
  # @return [Array<Target>] The players, nearest first.
  def self.targets
    raid = MGQ_MpCoop::Scope.raid?
    targets = MGQ_MpOverworldSync::Peers.all.map do |peer|
      next nil unless peer.ghost && MGQ_MpOverworldSync::Peers.on_this_map?(peer) && (peer.member || raid)

      target = target_of(peer)
      off_screen?(target.screen_x, target.screen_y) ? target : nil
    end
    targets.compact.sort_by { |target| [target.tiles, target.id] }.first(MAX_ARROWS)
  end

  # Measures a player on this map.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player, with a ghost.
  # @return [Target] The measure.
  def self.target_of(peer)
    ghost = peer.ghost
    tiles = ghost.distance_x_from($game_player.x).abs + ghost.distance_y_from($game_player.y).abs
    Target.new(peer, ghost.screen_x, ghost.screen_y - HALF_TILE, tiles)
  end

  # Reports whether a point lies off the screen.
  #
  # @param x [Integer] The point's x on the screen.
  # @param y [Integer] The point's y on the screen.
  # @return [Boolean] Whether it does.
  def self.off_screen?(x, y)
    x < 0 || y < 0 || x >= Graphics.width || y >= Graphics.height
  end

  # The rect the arrows' centers stay in: the screen less MARGIN on each side, and less the strip
  # of the mod at the top (see MGQ_MpUi.top_room).
  #
  # @return [Array(Integer, Integer, Integer, Integer)] Left, top, right and bottom.
  def self.edge_rect
    [MARGIN, MARGIN + MGQ_MpUi.top_room, Graphics.width - MARGIN, Graphics.height - MARGIN]
  end

  # Finds where an arrow sits and which way it points: where the line from one point of the screen
  # to another crosses edge_rect, kept inside the rect, and the line's angle.
  #
  # @param from_x [Integer] Where the line starts, x: the player's sprite.
  # @param from_y [Integer] Where the line starts, y.
  # @param to_x [Integer] Where it points, x: the other player's ghost.
  # @param to_y [Integer] Where it points, y.
  # @return [Array(Integer, Integer, Integer), nil] The arrow's x and y, and the angle in degrees,
  #   0 to the right and 90 down since the screen's y points down; nil for two equal points.
  def self.point(from_x, from_y, to_x, to_y)
    dx = (to_x - from_x).to_f
    dy = (to_y - from_y).to_f
    return nil if dx == 0 && dy == 0

    left, top, right, bottom = edge_rect
    reach = [axis_reach(from_x, dx, left, right), axis_reach(from_y, dy, top, bottom), 1.0].min
    reach = 0.0 if reach < 0
    x = MGQ_MpUi.within((from_x + dx * reach).round, left, right)
    y = MGQ_MpUi.within((from_y + dy * reach).round, top, bottom)
    [x, y, (Math.atan2(dy, dx) * HALF_TURN / Math::PI).round]
  end

  # Tells how far along a line, 1.0 for its whole length, it reaches one axis's bound.
  #
  # @param from [Integer] Where the line starts on the axis.
  # @param delta [Float] How far it goes on the axis.
  # @param low [Integer] The lower bound.
  # @param high [Integer] The upper bound.
  # @return [Float] The share of the line, 1.0 for a line still on the axis.
  def self.axis_reach(from, delta, low, high)
    return 1.0 if delta == 0

    delta > 0 ? (high - from) / delta : (low - from) / delta
  end

  # Tells how far from the triangle's center, along the line and away from the edge, the plate's
  # center lies so that the plate's nearest point clears the triangle by LABEL_GAP: the plate's
  # edge faces the triangle when the line meets the plate across its width or its height, else a
  # corner does, which lies on the circle of the gap.
  #
  # @param ux [Float] The angle's cosine.
  # @param uy [Float] The angle's sine.
  # @param half_width [Float] Half the plate's width.
  # @param half_height [Float] Half the plate's height.
  # @return [Float] The distance in pixels.
  def self.plate_distance(ux, uy, half_width, half_height)
    clear = REACH + LABEL_GAP
    ax = ux.abs
    ay = uy.abs
    across_height = ay > 0 ? (clear + half_height) / ay : nil
    return across_height if across_height && ax * across_height <= half_width

    across_width = ax > 0 ? (clear + half_width) / ax : nil
    return across_width if across_width && ay * across_width <= half_height

    support = ax * half_width + ay * half_height
    support + Math.sqrt([support ** 2 - half_width ** 2 - half_height ** 2 + clear ** 2, 0].max)
  end

  # Rounds an angle to the nearest ANGLE_STEP, so the arrow is drawn anew only once it turned.
  #
  # @param angle [Integer] The angle in degrees.
  # @return [Integer] The angle rounded.
  def self.step_angle(angle)
    (angle / ANGLE_STEP.to_f).round * ANGLE_STEP
  end

  # Fills a triangle row by row, since a Bitmap draws only rects.
  #
  # @param bitmap [Bitmap] The picture.
  # @param points [Array<Array(Float, Float)>] The three corners.
  # @param color [Color] The fill.
  def self.fill_triangle(bitmap, points, color)
    ys = points.map { |point| point[1] }
    (ys.min.floor..ys.max.ceil).each do |y|
      crossings = []
      points.each_with_index do |a, index|
        b = points[(index + 1) % points.size]
        next if a[1] == b[1] || y < [a[1], b[1]].min || y > [a[1], b[1]].max

        crossings << a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])
      end
      next if crossings.empty?

      left = crossings.min.floor
      bitmap.fill_rect(left, y, crossings.max.ceil - left + 1, 1, color)
    end
  end

  # Logs the arrows that appeared and went since the last frame, and a reason that hides them all
  # once it starts and once it ends; the arrows kept while a reason hides them are not logged
  # again when it ends.
  #
  # @param reason [String, nil] Why no arrow shows, see hidden_reason.
  # @param targets [Array<Target>] The players pointed at.
  def self.note(reason, targets)
    if reason != @reason
      log(reason ? "arrows hidden: #{reason}" : "arrows shown again")
      @reason = reason
    end
    return if reason

    now = {}
    targets.each do |target|
      who = @shown[target.id]
      unless who
        who = MGQ_MpOverworldSync.who(target.peer)
        log("an arrow for #{who} appeared, #{target.tiles} tiles away, in #{MGQ_MpUi::PlayerColor.label(target.peer)}")
      end
      now[target.id] = who
    end
    (@shown.keys - now.keys).each { |id| log("the arrow for #{@shown[id]} is gone: #{gone_reason(id)}") }
    @shown = now
  end

  # Tells why a player's arrow went.
  #
  # @param id [String] The player's id.
  # @return [String] The reason.
  def self.gone_reason(id)
    peer = MGQ_MpOverworldSync::Peers.all.find { |other| other.state["id"].to_s == id }
    return "they left the world" unless peer
    return "their connection is down" if peer.away
    return "they left the map" unless peer.ghost && MGQ_MpOverworldSync::Peers.on_this_map?(peer)
    return "they are not in the party" unless peer.member || MGQ_MpCoop::Scope.raid?

    target = target_of(peer)
    off_screen?(target.screen_x, target.screen_y) ? "others are nearer" : "they are on the screen"
  end

  # Forgets which arrows were logged as shown, when the map's sprites go.
  def self.forget
    @shown = {}
  end

  # The arrows of one map, one sprite each, kept and given to the players as they come and go.
  class Pool
    # Most sprites kept: the arrows shown and those still fading out; past them an arrow fading
    # out is given to a new player.
    LIMIT = MAX_ARROWS * 2

    # Creates an empty pool.
    #
    # @param viewport [Viewport] The map's topmost viewport.
    def initialize(viewport)
      @viewport = viewport
      @arrows = []
    end

    # Points the arrows at the players to point at, hides the others, and moves them all one frame;
    # a frame that fails fades every arrow out, so none stays frozen. Called by the map every frame.
    def update
      reason = MGQ_MpEdgeArrows.hidden_reason
      targets = reason ? [] : MGQ_MpEdgeArrows.targets
      MGQ_MpEdgeArrows.note(reason, targets)
      from = [$game_player.screen_x, $game_player.screen_y - HALF_TILE]
      taken = []
      targets.each do |target|
        arrow = @arrows.find { |candidate| candidate.id == target.id } || free_arrow(taken)
        arrow.show(target, from)
        taken << arrow
      end
      move(taken)
    rescue => e
      MGQ_MpEdgeArrows.log_once(:update, "the arrows failed: #{e.class}: #{e.message}")
      move([])
    end

    # Hides every arrow but the ones given to players this frame, and moves them all one frame.
    #
    # @param taken [Array<Sprite_MpEdgeArrow>] The arrows given to players this frame.
    def move(taken)
      @arrows.each do |arrow|
        arrow.hide unless taken.include?(arrow)
        arrow.update
      end
    end

    # Finds a sprite for a new player: one hidden, else a new one while the pool is below LIMIT,
    # else the one furthest faded out.
    #
    # @param taken [Array<Sprite_MpEdgeArrow>] The arrows given to players this frame.
    # @return [Sprite_MpEdgeArrow] The sprite.
    def free_arrow(taken)
      free = @arrows.reject { |arrow| taken.include?(arrow) }
      arrow = free.find { |candidate| candidate.hidden? }
      return arrow if arrow
      return (@arrows << Sprite_MpEdgeArrow.new(@viewport)).last if @arrows.size < LIMIT

      free.min_by { |candidate| candidate.opacity }
    end

    # The sprites, for the tests.
    #
    # @return [Array<Sprite_MpEdgeArrow>] The sprites.
    def arrows
      @arrows
    end

    # Frees the sprites, with the map's.
    def dispose
      @arrows.each { |arrow| arrow.dispose }
      @arrows = []
      MGQ_MpEdgeArrows.forget
    end
  end
end

# One arrow: a triangle pointing along its angle, its center at the sprite's place, and the plate
# with the name and the tiles on the side away from the edge. Drawn anew only when the name, the
# tiles, the color or the stepped angle changed.
class Sprite_MpEdgeArrow < Sprite
  # The player the arrow points at.
  #
  # @return [String] Their id, "" before the first player.
  attr_reader :id

  # Creates the arrow, hidden.
  #
  # @param viewport [Viewport] The map's topmost viewport.
  def initialize(viewport)
    super(viewport)
    self.z = MGQ_MpUi::Z[:arrows]
    @id = ""
    @drawn = nil
    @motion = MGQ_MpUi::Motion.new(self)
    @measure = Bitmap.new(1, 1)
  end

  # Points the arrow at a player and shows it.
  #
  # @param target [MGQ_MpEdgeArrows::Target] The player.
  # @param from [Array(Integer, Integer)] Where the player's own sprite is on the screen.
  def show(target, from)
    point = MGQ_MpEdgeArrows.point(from[0], from[1], target.screen_x, target.screen_y)
    return hide unless point

    @id = target.id
    angle = MGQ_MpEdgeArrows.step_angle(point[2])
    color = MGQ_MpUi::PlayerColor.of(target.peer)
    key = [@id, target.name, target.tiles, angle, color]
    unless key == @drawn
      @drawn = key
      draw(target, angle, color)
    end
    @motion.place(point[0], point[1])
    radians = angle * Math::PI / MGQ_MpEdgeArrows::HALF_TURN
    @motion.show((Math.cos(radians) * MGQ_MpEdgeArrows::SLIDE_PIXELS).round, (Math.sin(radians) * MGQ_MpEdgeArrows::SLIDE_PIXELS).round)
  end

  # Fades the arrow out.
  def hide
    @motion.hide
  end

  # Moves the fade one frame.
  def update
    super
    @motion.update
  end

  # Reports whether the arrow is invisible: faded out or never shown.
  #
  # @return [Boolean] Whether it is.
  def hidden?
    @motion.hidden?
  end

  # Reports whether the arrow is shown or fading in.
  #
  # @return [Boolean] Whether it is.
  def shown?
    @motion.shown?
  end

  # Frees the picture and the measuring bitmap with the sprite.
  def dispose
    bitmap.dispose if bitmap && !bitmap.disposed?
    @measure.dispose
    super
  end

  # Draws the triangle and the plate into a picture just big enough for both, the triangle's
  # center at the sprite's ox and oy.
  #
  # @param target [MGQ_MpEdgeArrows::Target] The player.
  # @param angle [Integer] The stepped angle in degrees.
  # @param color [Color] The player's color.
  def draw(target, angle, color)
    style = MGQ_MpUi::Style
    arrows = MGQ_MpEdgeArrows
    radians = angle * Math::PI / arrows::HALF_TURN
    ux = Math.cos(radians)
    uy = Math.sin(radians)

    style.use_font(@measure, style::SMALL_SIZE, color)
    text = arrows::LABEL % [MGQ_MpUi.cut(@measure, target.name, arrows::NAME_WIDTH), target.tiles]
    label_width = @measure.text_size(text).width + 2 * style::PAD

    half_width = label_width / 2.0
    half_height = arrows::LABEL_HEIGHT / 2.0
    distance = arrows.plate_distance(ux, uy, half_width, half_height)
    label_left = -ux * distance - half_width
    label_top = -uy * distance - half_height

    left = [-arrows::REACH, label_left].min.floor
    top = [-arrows::REACH, label_top].min.floor
    right = [arrows::REACH, label_left + label_width].max.ceil
    bottom = [arrows::REACH, label_top + arrows::LABEL_HEIGHT].max.ceil
    bitmap.dispose if bitmap && !bitmap.disposed?
    self.bitmap = Bitmap.new(right - left, bottom - top)
    self.ox = -left
    self.oy = -top

    draw_triangle(ox, oy, ux, uy, color)
    style.use_font(bitmap, style::SMALL_SIZE, color)
    style.draw_plated(bitmap, (label_left - left).round, (label_top - top).round, label_width, arrows::LABEL_HEIGHT, text)
  end

  # Fills the triangle with its tip along the angle, in its solid outline.
  #
  # @param cx [Integer] The triangle's center in the picture, x.
  # @param cy [Integer] The triangle's center in the picture, y.
  # @param ux [Float] The angle's cosine.
  # @param uy [Float] The angle's sine.
  # @param color [Color] The fill.
  def draw_triangle(cx, cy, ux, uy, color)
    arrows = MGQ_MpEdgeArrows
    style = MGQ_MpUi::Style
    half_length = arrows::LENGTH / 2.0
    half_width = arrows::WIDTH / 2.0
    corners = [
      [cx + ux * half_length, cy + uy * half_length],
      [cx - ux * half_length - uy * half_width, cy - uy * half_length + ux * half_width],
      [cx - ux * half_length + uy * half_width, cy - uy * half_length - ux * half_width],
    ]
    reach = style::OUTLINE_REACH
    [[-reach, 0], [reach, 0], [0, -reach], [0, reach]].each do |dx, dy|
      arrows.fill_triangle(bitmap, corners.map { |x, y| [x + dx, y + dy] }, style::OUTLINE)
    end
    arrows.fill_triangle(bitmap, corners, color)
  end
end

begin
  # After the map's sprites, the arrows toward the players off the screen.
  MGQ_MpHooks.after(Spriteset_Map, :update, "ui_edge_arrows") { (@mgq_mp_edge_arrows ||= MGQ_MpEdgeArrows::Pool.new(@viewport3)).update }

  MGQ_MpHooks.before(Spriteset_Map, :dispose, "ui_edge_arrows") do
    @mgq_mp_edge_arrows.dispose if @mgq_mp_edge_arrows
    @mgq_mp_edge_arrows = nil
  end
rescue => e
  MGQ_MpEdgeArrows.log("hooks FAILED: #{e.class}: #{e.message}")
end
