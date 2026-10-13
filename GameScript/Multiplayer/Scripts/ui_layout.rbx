#----------------------------------------------------------------
#  ui_layout.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

module MGQ_MpUi
  # Where the mod's floating boxes lie and how large they are, which the player changes with the
  # left Alt held: a drag inside a box moves it, a drag on its edge or corner resizes it, a double
  # click puts it back where it starts. Each box keeps its place in Player.ini, never smaller than
  # the least it needs to show all it has.
  #
  # A box registers once with its name and least size, asks rect for where to draw each frame, and
  # offers where it drew while it shows; the tick after Graphics.update reads the mouse against the
  # boxes offered in the frame before and, while Alt is held, outlines them above everything.
  #
  # It must never interrupt the game, so every entry point rescues.
  module Layout
    extend MGQ_MpLog

    # What starts this script's lines in Multiplayer InGame.log.
    LOG_TAG = "layout"

    # Windows' code of the left Alt; the right Alt is AltGr, which types characters.
    ALT_KEY = 0xA4

    # Windows' code of the left mouse button.
    LEFT_BUTTON = 0x01

    # What starts a box's setting in Player.ini, followed by its id: "x,y,width,height".
    SETTING_PREFIX = "ui_"

    # Pixels inside a box's border on which a drag resizes it rather than moving it.
    GRAB = 8

    # Frames within which a second click counts as a double click.
    DOUBLE_CLICK_FRAMES = 24

    # Pixels a double click's second click may lie from the first, along either axis.
    DOUBLE_CLICK_REACH = 6

    # How a box may be resized: both ways, in width alone, its height following what it shows, or
    # not at all.
    RESIZES = [:both, :width, :none]

    # Color of every box's outline while Alt is held.
    OUTLINE = Color.new(255, 255, 255, 200)

    # Color of the light wash over the box under the mouse or being dragged.
    WASH = Color.new(255, 255, 255, 36)

    # Side of the grip drawn into a resizable box's bottom right corner while Alt is held.
    GRIP = 10

    # What the screen says at its bottom while Alt is held.
    HINT = "Alt + drag: move   Drag an edge: resize   Double-click: reset"

    # Height of the hint's plate.
    HINT_HEIGHT = 22

    # The Mod Config row's key.
    OPTION = :mp_ui_positions

    # The Mod Config row's name.
    OPTION_NAME = "Interface Positions"

    # The Mod Config row's help.
    OPTION_HELP = "Hold the left Alt: drag a box of the mod to move it, its edge to resize it, and double-click one to put it back.\n" \
                  "Pick Default to put every box back where it starts."

    # The row's value while any box was moved.
    MOVED = "Moved"

    # The row's value that puts every box back.
    DEFAULT = "Default"

    # A box the player can move: its name for the log and the outline, its least size and how it
    # resizes, see RESIZES.
    Box = Struct.new(:name, :min_width, :min_height, :resize)

    # Where a box drew in the frame before, its depth deciding which of two overlapping boxes a
    # click takes.
    Offer = Struct.new(:id, :rect, :z)

    # A drag under way: its box, where the mouse went down, the box's place then, which sides follow
    # the mouse (left, top, right, bottom; none to move it) and the place it has now.
    Drag = Struct.new(:id, :start, :origin, :sides, :rect)

    # The registered boxes, by their ids.
    @boxes = {}

    # Where the player left each box read so far, nil for one at its default, by the boxes' ids.
    @stored = {}

    # The boxes offered since the last tick.
    @offers = []

    # The ticks so far, which time a double click.
    @frame = 0

    # Makes a box movable.
    #
    # @param id [Symbol] The box, which names its setting.
    # @param name [String] Its name for the outline and the log.
    # @param min_width [Integer] The narrowest it gets.
    # @param min_height [Integer] The lowest it gets.
    # @param resize [Symbol] How it resizes, see RESIZES.
    def self.register(id, name, min_width, min_height, resize = :both)
      @boxes[id] = Box.new(name, min_width, min_height, RESIZES.include?(resize) ? resize : :both)
    end

    # Tells where a box draws: where it is being dragged, else where the player left it, else its
    # default, at least its least size and wholly on the screen.
    #
    # @param id [Symbol] The box.
    # @param default [Rect] Where it starts.
    # @return [Rect] Where it draws.
    def self.rect(id, default)
      box = @boxes[id] || Box.new(id.to_s, 0, 0, :both)
      return copy(@drag.rect) if @drag && @drag.id == id

      kept = stored(id)
      kept ? fit(box, kept, default) : fit(box, default, default)
    rescue => e
      log_once([:rect, id], "place of #{id} FAILED: #{e.class}: #{e.message}")
      default
    end

    # Tells whether a box lies where the player left it rather than at its default.
    #
    # @param id [Symbol] The box.
    # @return [Boolean] Whether it does.
    def self.moved?(id)
      !stored(id).nil?
    end

    # Tells whether a box is being dragged.
    #
    # @param id [Symbol] The box.
    # @return [Boolean] Whether it is.
    def self.dragging?(id)
      @drag && @drag.id == id ? true : false
    end

    # Tells whether the player is arranging the boxes: the left Alt is held, so the mouse moves and
    # resizes them instead of clicking.
    #
    # @return [Boolean] Whether they are.
    def self.arranging?
      MGQ_Multiplayer::Key.down?(ALT_KEY) || !@drag.nil?
    end

    # Offers where a box drew this frame, so a drag can take it and the outline show it.
    #
    # @param id [Symbol] The box.
    # @param x [Integer] Its left on the screen.
    # @param y [Integer] Its top on the screen.
    # @param width [Integer] Its width.
    # @param height [Integer] Its height.
    # @param z [Integer] Its depth.
    def self.offer(id, x, y, width, height, z = 0)
      @offers.reject! { |offer| offer.id == id }
      @offers << Offer.new(id, Rect.new(x.to_i, y.to_i, width.to_i, height.to_i), z.to_i)
    end

    # Puts a box back where it starts.
    #
    # @param id [Symbol] The box.
    # @param why [String] What put it back, for the log.
    def self.reset(id, why)
      @stored.delete(id)
      @drag = nil if @drag && @drag.id == id
      MGQ_Multiplayer::Player.forget(SETTING_PREFIX + id.to_s)
      log("put #{name_of(id)} back (#{why})")
    end

    # Puts every box back where it starts.
    #
    # @param why [String] What put them back, for the log.
    def self.reset_all(why)
      @boxes.keys.each { |id| reset(id, why) if moved?(id) }
    end

    # Tells whether any box lies where the player left it.
    #
    # @return [Boolean] Whether one does.
    def self.any_moved?
      @boxes.keys.any? { |id| moved?(id) }
    end

    # Follows the mouse and draws the outlines, once a frame after Graphics.update, against the boxes
    # offered since the tick before.
    def self.tick
      @frame += 1
      offers = @offers
      @offers = []
      alt = MGQ_Multiplayer::Key.down?(ALT_KEY)
      held = MGQ_Multiplayer::Key.down?(LEFT_BUTTON)
      went_down = held && !@held
      @held = held
      position = alt || @drag ? MGQ_Multiplayer::Mouse.position : nil
      if @drag
        follow(position, held)
      elsif alt && went_down && position
        grab(offers, position)
      end
      draw(alt || @drag ? offers : [], position)
    rescue => e
      log_once([:tick, e.class], "tick FAILED: #{e.class}: #{e.message}")
    end

    # Starts a drag on the topmost box under the mouse, or puts it back on a double click.
    #
    # @param offers [Array<Offer>] The boxes shown.
    # @param position [Array<Integer>] Where the mouse went down.
    def self.grab(offers, position)
      offer = top_offer(offers, position)
      return unless offer

      if double_click?(offer.id, position)
        @last_click = nil
        return reset(offer.id, "a double click with Alt")
      end

      @last_click = [offer.id, position, @frame]
      box = @boxes[offer.id] || Box.new(offer.id.to_s, 0, 0, :none)
      @drag = Drag.new(offer.id, position, copy(offer.rect), sides_at(box, offer.rect, position), copy(offer.rect))
    end

    # Finds the topmost box under a point.
    #
    # @param offers [Array<Offer>] The boxes shown.
    # @param position [Array<Integer>] The point.
    # @return [Offer, nil] The box, nil for none.
    def self.top_offer(offers, position)
      offers.select { |offer| inside?(offer.rect, position) }.max_by { |offer| offer.z }
    end

    # Tells whether a click is the second of a double click on a box.
    #
    # @param id [Symbol] The box clicked.
    # @param position [Array<Integer>] Where.
    # @return [Boolean] Whether it is.
    def self.double_click?(id, position)
      return false unless @last_click

      last_id, last_position, last_frame = @last_click
      last_id == id && @frame - last_frame <= DOUBLE_CLICK_FRAMES &&
        (position[0] - last_position[0]).abs <= DOUBLE_CLICK_REACH && (position[1] - last_position[1]).abs <= DOUBLE_CLICK_REACH
    end

    # Finds which sides of a box a drag from a point resizes: those whose border within GRAB the
    # point lies on, as the box resizes; none moves the box.
    #
    # @param box [Box] The box.
    # @param rect [Rect] Where it lies.
    # @param position [Array<Integer>] The point.
    # @return [Array<Boolean>] Left, top, right and bottom.
    def self.sides_at(box, rect, position)
      return [false, false, false, false] if box.resize == :none

      left = position[0] < rect.x + GRAB
      right = position[0] >= rect.x + rect.width - GRAB
      top = box.resize == :both && position[1] < rect.y + GRAB
      bottom = box.resize == :both && position[1] >= rect.y + rect.height - GRAB
      [left, top, right && !left, bottom && !top]
    end

    # Follows the mouse while a drag runs and keeps the box's place once the button is let go.
    #
    # @param position [Array<Integer>, nil] Where the mouse points, nil outside the window.
    # @param held [Boolean] Whether the left button is still held.
    def self.follow(position, held)
      drag = @drag
      box = @boxes[drag.id] || Box.new(drag.id.to_s, 0, 0, :none)
      drag.rect = dragged(box, drag, position) if position
      finish(drag) unless held
    end

    # Ends a drag, keeping the box's place in Player.ini unless it never moved.
    #
    # @param drag [Drag] The drag.
    def self.finish(drag)
      @drag = nil
      rect = drag.rect
      return if same?(rect, drag.origin)

      @stored[drag.id] = copy(rect)
      MGQ_Multiplayer::Player.store(SETTING_PREFIX + drag.id.to_s, [rect.x, rect.y, rect.width, rect.height].join(","))
      @last_click = nil
      log("#{drag.sides.any? ? 'resized' : 'moved'} #{name_of(drag.id)} to #{rect.x},#{rect.y} at #{rect.width}x#{rect.height}")
    end

    # Finds a dragged box's place: moved by how far the mouse went, or its sides that follow the
    # mouse moved, never past its least size and never off the screen.
    #
    # @param box [Box] The box.
    # @param drag [Drag] The drag.
    # @param position [Array<Integer>] Where the mouse points.
    # @return [Rect] The place.
    def self.dragged(box, drag, position)
      dx = position[0] - drag.start[0]
      dy = position[1] - drag.start[1]
      origin = drag.origin
      unless drag.sides.any?
        moved = Rect.new(origin.x + dx, origin.y + dy, origin.width, origin.height)
        return on_screen(moved)
      end

      left_side, top_side, right_side, bottom_side = drag.sides
      left, right = span(origin.x, origin.x + origin.width, left_side ? dx : 0, right_side ? dx : 0, box.min_width, screen_width)
      top, bottom = span(origin.y, origin.y + origin.height, top_side ? dy : 0, bottom_side ? dy : 0, box.min_height, screen_height)
      Rect.new(left, top, right - left, bottom - top)
    end

    # Moves the two ends of a span by a drag, keeping it at least its least length and within
    # 0..limit; the end that does not move stays put.
    #
    # @param low [Integer] Its start.
    # @param high [Integer] Its end.
    # @param low_step [Integer] How far its start moves.
    # @param high_step [Integer] How far its end moves.
    # @param least [Integer] Its least length.
    # @param limit [Integer] Where the screen ends.
    # @return [Array(Integer, Integer)] The new start and end.
    def self.span(low, high, low_step, high_step, least, limit)
      least = [least, limit].min
      if low_step != 0
        low = MGQ_MpUi.within(low + low_step, 0, high - least)
      elsif high_step != 0
        high = MGQ_MpUi.within(high + high_step, low + least, limit)
      end
      [low, high]
    end

    # Fits a box's place: at least its least size, at most the screen, wholly on the screen; a box
    # that resizes in width alone, or not at all, keeps its default's height, or its width too.
    #
    # @param box [Box] The box.
    # @param rect [Rect] Its place.
    # @param default [Rect] Where it starts.
    # @return [Rect] The fitted place.
    def self.fit(box, rect, default)
      width = box.resize == :none ? default.width : rect.width
      height = box.resize == :both ? rect.height : default.height
      width = MGQ_MpUi.within(width, box.min_width, screen_width)
      height = MGQ_MpUi.within(height, box.min_height, screen_height)
      on_screen(Rect.new(rect.x, rect.y, width, height))
    end

    # Keeps a place wholly on the screen, its size as it is.
    #
    # @param rect [Rect] The place.
    # @return [Rect] The place moved onto the screen.
    def self.on_screen(rect)
      width = [rect.width, screen_width].min
      height = [rect.height, screen_height].min
      Rect.new(MGQ_MpUi.within(rect.x, 0, screen_width - width), MGQ_MpUi.within(rect.y, 0, screen_height - height), width, height)
    end

    # Reads where the player left a box, from Player.ini once.
    #
    # @param id [Symbol] The box.
    # @return [Rect, nil] The place, nil while it lies at its default.
    def self.stored(id)
      return @stored[id] if @stored.key?(id)

      text = MGQ_Multiplayer::Player.setting(SETTING_PREFIX + id.to_s).to_s
      numbers = text.split(",").map { |part| part.strip }
      @stored[id] = numbers.size == 4 && numbers.all? { |part| part =~ /\A-?\d+\z/ } ? Rect.new(*numbers.map { |part| part.to_i }) : nil
    end

    # Draws the outlines of the boxes shown while Alt is held, if they changed: every box framed,
    # the one under the mouse or being dragged washed, a grip in each resizable box's corner, its
    # name at its top left, and the hint at the screen's bottom.
    #
    # @param offers [Array<Offer>] The boxes to outline, none while Alt is let go.
    # @param position [Array<Integer>, nil] Where the mouse points.
    def self.draw(offers, position)
      shown = offers.empty? ? nil : [offers.map { |offer| [offer.id, offer.rect.x, offer.rect.y, offer.rect.width, offer.rect.height] }.sort_by { |row| row[0].to_s },
                                     hot_id(offers, position), Theme.serial]
      return if shown == @shown

      @shown = shown
      sprite = overlay
      bitmap = sprite.bitmap
      bitmap.clear
      sprite.visible = !shown.nil?
      return unless shown

      hot = shown[1]
      offers.sort_by { |offer| offer.z }.each { |offer| draw_outline(bitmap, offer, offer.id == hot) }
      style = Style
      style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
      style.draw_plated(bitmap, 0, bitmap.height - HINT_HEIGHT - style::PAD, bitmap.width, HINT_HEIGHT, HINT)
    end

    # Finds the box the outline washes: the one being dragged, else the topmost under the mouse.
    #
    # @param offers [Array<Offer>] The boxes shown.
    # @param position [Array<Integer>, nil] Where the mouse points.
    # @return [Symbol, nil] The box, nil for none.
    def self.hot_id(offers, position)
      return @drag.id if @drag
      return nil unless position

      offer = top_offer(offers, position)
      offer ? offer.id : nil
    end

    # Draws one box's outline, see draw.
    #
    # @param bitmap [Bitmap] The overlay's picture.
    # @param offer [Offer] The box.
    # @param hot [Boolean] Whether it is under the mouse or being dragged.
    def self.draw_outline(bitmap, offer, hot)
      rect = offer.rect
      bitmap.fill_rect(rect.x, rect.y, rect.width, rect.height, WASH) if hot
      Style.draw_line_box(bitmap, rect.x, rect.y, rect.width, rect.height, OUTLINE)
      box = @boxes[offer.id]
      draw_grip(bitmap, rect) if box && box.resize != :none
      style = Style
      style.use_font(bitmap, style::TINY_SIZE, style::TEXT)
      style.draw_plated(bitmap, rect.x + 2, rect.y + 2, rect.width - 4, style::TINY_SIZE + 4, name_of(offer.id), 0)
    end

    # Draws the grip into a box's bottom right corner: a small stepped triangle.
    #
    # @param bitmap [Bitmap] The overlay's picture.
    # @param rect [Rect] The box.
    def self.draw_grip(bitmap, rect)
      right = rect.x + rect.width - 2
      bottom = rect.y + rect.height - 2
      (0...GRIP).step(3) { |step| bitmap.fill_rect(right - step, bottom - GRIP + step, step + 1, 1, OUTLINE) }
    end

    # Hands out the overlay the outlines are drawn on, a sprite over the whole screen above
    # everything, made anew once the screen's size changes or it was freed.
    #
    # @return [Sprite] The overlay.
    def self.overlay
      sprite = @overlay
      fits = sprite && !sprite.disposed? && sprite.bitmap && !sprite.bitmap.disposed? &&
             sprite.bitmap.width == screen_width && sprite.bitmap.height == screen_height
      return sprite if fits

      sprite.dispose if sprite && !sprite.disposed?
      @overlay = Sprite.new
      @overlay.z = MGQ_MpUi::Z[:layout]
      @overlay.bitmap = Bitmap.new(screen_width, screen_height)
      @overlay
    end

    # Names a box for the log and its outline.
    #
    # @param id [Symbol] The box.
    # @return [String] Its name.
    def self.name_of(id)
      box = @boxes[id]
      box ? box.name : id.to_s
    end

    # Tells whether a point lies inside a place.
    #
    # @param rect [Rect] The place.
    # @param position [Array<Integer>] The point.
    # @return [Boolean] Whether it does.
    def self.inside?(rect, position)
      position[0] >= rect.x && position[0] < rect.x + rect.width && position[1] >= rect.y && position[1] < rect.y + rect.height
    end

    # Tells whether two places are the same.
    #
    # @param one [Rect] One place.
    # @param other [Rect] The other.
    # @return [Boolean] Whether they are.
    def self.same?(one, other)
      [one.x, one.y, one.width, one.height] == [other.x, other.y, other.width, other.height]
    end

    # Copies a place, so no box changes the layout's own.
    #
    # @param rect [Rect] The place.
    # @return [Rect] The copy.
    def self.copy(rect)
      Rect.new(rect.x, rect.y, rect.width, rect.height)
    end

    # Tells the screen's width.
    #
    # @return [Integer] Its pixels.
    def self.screen_width
      Graphics.width
    end

    # Tells the screen's height.
    #
    # @return [Integer] Its pixels.
    def self.screen_height
      Graphics.height
    end

    # Offers the places as a row of the Mod Config: Moved while any box was moved, and Default,
    # which puts every box back.
    def self.add_option
      values = lambda { any_moved? ? [MOVED, DEFAULT] : [DEFAULT] }
      read = lambda { any_moved? ? MOVED : DEFAULT }
      write = lambda { |value| reset_all("picked Default in the Mod Config") if value == DEFAULT }
      added = MGQ_MpUi.add_option(OPTION, OPTION_NAME, OPTION_HELP, values, read, write)
      log(added ? "added the interface positions to the Mod Config" : "no interface positions in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
    end
  end
end

begin
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "ui_layout") { MGQ_MpUi::Layout.tick }
  MGQ_MpUi::Layout.add_option
rescue => e
  MGQ_MpUi::Layout.log("start FAILED: #{e.class}: #{e.message}")
end
