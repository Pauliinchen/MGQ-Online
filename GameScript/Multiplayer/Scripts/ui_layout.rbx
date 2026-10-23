#----------------------------------------------------------------
#  ui_layout.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Left the fitting, the drags and the double click to C#, keeping the places it answers
#                            - Removed dragging?, which only the tests read
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
  # offers where it drew while it shows. C# keeps the rules (LayoutModel in MGQOnline.Game's Ui):
  # the fitting, the drags and the double click; the frame's tick hands it the mouse against the
  # boxes offered in the frame before while Alt is held, its events keep the places and Player.ini
  # up to date, and the overlay outlines the boxes above everything here.
  #
  # It must never interrupt the game, so every entry point rescues.
  module Layout
    extend MGQ_MpLog

    # What starts this script's lines in the log.
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

    # Makes a box movable in C#, LayoutModel.RegisterTopic.
    REGISTER = "ui.layout.register"

    # Tells where a box draws, LayoutModel.RectTopic.
    RECT = "ui.layout.rect"

    # Puts a box back, LayoutModel.ResetTopic.
    RESET = "ui.layout.reset"

    # The layout's event, LayoutModel.EventTopic.
    EVENT = "ui.layout"

    # The layout's name in the tick.
    MODEL = "layout"

    # The registered boxes, by their ids.
    @boxes = {}

    # Where each box draws as C# answered: the default and the screen it answered for, and the
    # place, by the boxes' ids.
    @stored = {}

    # Whether the player moved each box, by the boxes' ids.
    @moved = {}

    # The boxes offered since the last tick.
    @offers = []

    # Whether a drag runs, as C# said.
    @dragging = false

    # The box under the mouse or being dragged, as C# said.
    @hot = nil

    # Makes a box movable, handing C# where Player.ini keeps it.
    #
    # @param id [Symbol] The box, which names its setting.
    # @param name [String] Its name for the outline and the log.
    # @param min_width [Integer] The narrowest it gets.
    # @param min_height [Integer] The lowest it gets.
    # @param resize [Symbol] How it resizes, see RESIZES.
    def self.register(id, name, min_width, min_height, resize = :both)
      box = @boxes[id] = Box.new(name, min_width, min_height, RESIZES.include?(resize) ? resize : :both)
      @stored.delete(id)
      moved = MGQ_Multiplayer::Bridge.call(REGISTER, [id.to_s, name.to_s, min_width.to_i, min_height.to_i, box.resize.to_s, stored_text(id)])
      @moved[id] = moved == true
    end

    # Tells where a box draws, as C# answers: where it is being dragged, else where the player left
    # it, else its default, at least its least size and wholly on the screen. C# is asked once per
    # default and screen; its events keep the answer up to date.
    #
    # @param id [Symbol] The box.
    # @param default [Rect] Where it starts.
    # @return [Rect] Where it draws; its default while the bridge is closed.
    def self.rect(id, default)
      key = [default.x, default.y, default.width, default.height, screen_width, screen_height]
      kept = @stored[id]
      return copy(kept[1]) if kept && kept[0] == key

      answer = MGQ_Multiplayer::Bridge.call(RECT, [id.to_s] + key + [kept ? false : stored_text(id)])
      return default unless answer

      @moved[id] = answer[4] == true
      @stored[id] = [key, Rect.new(*answer[0, 4])]
      copy(@stored[id][1])
    rescue => e
      log_once([:rect, id], "place of #{id} FAILED: #{e.class}: #{e.message}")
      default
    end

    # Tells whether a box lies where the player left it rather than at its default.
    #
    # @param id [Symbol] The box.
    # @return [Boolean] Whether it does.
    def self.moved?(id)
      @moved[id] == true
    end

    # Tells whether the player is arranging the boxes: the left Alt is held, so the mouse moves and
    # resizes them instead of clicking.
    #
    # @return [Boolean] Whether they are.
    def self.arranging?
      MGQ_Multiplayer::Key.down?(ALT_KEY) || @dragging
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
      @moved[id] = false
      MGQ_Multiplayer::Player.forget(SETTING_PREFIX + id.to_s)
      MGQ_Multiplayer::Bridge.call(RESET, [id.to_s])
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

    # Hands C# the frame while the player arranges the boxes, and one frame more once they stop,
    # and draws the outlines: the left Alt, the left button, the mouse and the boxes offered since the
    # tick before. Called just before the frame's tick goes over.
    def self.tick
      offers = @offers
      @offers = []
      alt = MGQ_Multiplayer::Key.down?(ALT_KEY)
      held = MGQ_Multiplayer::Key.down?(LEFT_BUTTON)
      went_down = held && !@held
      @held = held
      arranging = alt || @dragging
      position = arranging ? MGQ_Multiplayer::Mouse.position : nil
      if arranging || @arranged
        MGQ_MpUi::Tick.put(MODEL, [alt, held, went_down, position && position[0], position && position[1], screen_width, screen_height,
                                   offers.map { |offer| [offer.id.to_s, offer.rect.x, offer.rect.y, offer.rect.width, offer.rect.height, offer.z] }])
      end
      @arranged = arranging
      draw(arranging ? offers : [], @hot)
    rescue => e
      log_once([:tick, e.class], "tick FAILED: #{e.class}: #{e.message}")
    end

    # Takes the layout's event: places changed, places kept or forgotten in Player.ini, the drag,
    # the box under the mouse, and the lines for the log.
    #
    # @param event [Hash] The event, see LayoutModel.EventTopic.
    def self.take_event(event)
      (event["rects"] || {}).each do |id, place|
        kept = @stored[id.to_sym]
        kept[1] = Rect.new(*place) if kept
      end
      (event["store"] || {}).each do |id, text|
        text ? MGQ_Multiplayer::Player.store(SETTING_PREFIX + id, text) : MGQ_Multiplayer::Player.forget(SETTING_PREFIX + id)
        @moved[id.to_sym] = !text.nil?
      end
      @dragging = event["dragging"] if event.key?("dragging")
      @hot = event["hot"] && event["hot"].to_sym if event.key?("hot")
      Array(event["log"]).each { |line| log(line) }
    end

    # Reads where Player.ini says the player left a box.
    #
    # @param id [Symbol] The box.
    # @return [String, nil] Its "x,y,width,height", nil for none.
    def self.stored_text(id)
      text = MGQ_Multiplayer::Player.setting(SETTING_PREFIX + id.to_s)
      text && text.to_s
    end

    # Draws the outlines of the boxes shown while Alt is held, if they changed: every box framed,
    # the one under the mouse or being dragged washed, a grip in each resizable box's corner, its
    # name at its top left, and the hint at the screen's bottom.
    #
    # @param offers [Array<Offer>] The boxes to outline, none while Alt is let go.
    # @param hot [Symbol, nil] The box C# says is under the mouse or being dragged.
    def self.draw(offers, hot)
      shown = offers.empty? ? nil : [offers.map { |offer| [offer.id, offer.rect.x, offer.rect.y, offer.rect.width, offer.rect.height] }.sort_by { |row| row[0].to_s },
                                     hot, Theme.serial]
      return if shown == @shown

      @shown = shown
      sprite = overlay
      bitmap = sprite.bitmap
      bitmap.clear
      sprite.visible = !shown.nil?
      return unless shown

      offers.sort_by { |offer| offer.z }.each { |offer| draw_outline(bitmap, offer, offer.id == hot) }
      style = Style
      style.use_font(bitmap, style::SMALL_SIZE, style::TEXT)
      style.draw_plated(bitmap, 0, bitmap.height - HINT_HEIGHT - style::PAD, bitmap.width, HINT_HEIGHT, HINT)
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
  MGQ_MpUi::Tick.collect { MGQ_MpUi::Layout.tick }
  MGQ_Multiplayer::Bridge.on(MGQ_MpUi::Layout::EVENT) { |event| MGQ_MpUi::Layout.take_event(event) }
  MGQ_MpUi::Layout.add_option
rescue => e
  MGQ_MpUi::Layout.log("start FAILED: #{e.class}: #{e.message}")
end
