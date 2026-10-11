#----------------------------------------------------------------
#  ui.rbx
#
#  Changelog:
#      Paulinchen  2026-10-11: Drew the list box and the message box in the shared style, dropping their own colors and font sizes, and faded the list box in and out
#                            - Placed the list box and the message box by the screen's size, cut a title and an item to its room, and named the numpad's 0 in the list box's hint
#                            - Drew a hint whole, smaller once it is wider than its room, since a cut would drop the keys it names at its end; the list box, the message box and the wheels share it
#                            - Added the fading of a text's color for a line about to go, which the notices and the chat log share, and dropped WHITE for the style's text
#                            - Added the shared style of the mod's flat boxes: its colors, font sizes, padding, column gap, timings, the outlined and plated texts the raid bar drew on its own, and the close hint every screen names its keys in
#                            - Added the motion of a sprite, a fade in and out with a slide, which the boxes and lines share, and its step towards a target, which the raid bar's slide shares
#                            - Added the color of a player: yellow for the player, green for a party member, one of eight by their id for anyone else
#                            - Added the confirm box, a yes or no question over any scene, answered in the tick after the one that read the answer and answered no once another scene starts
#                            - Named the frames the game draws in a second and how seconds are written, which the own line's seconds and the waiting box share
#                            - Added the icon drawn at any side, dim when asked, which the labels on the map, the boxes and the wheels share, and the room an icon takes in a row
#                            - Added the depth of the edge arrows under every line and box, and the bounds helper the arrows and the join prompt share
#                            - Added the rows a box shows of a longer list and how many more wait, which the notices and the party box share
#      Paulinchen  2026-10-10: Added the room a strip of the mod takes at the top of the map's screen and whole numbers grouped by commas
#      Paulinchen  2026-10-08: Added the depth of the chat while the player types, above everything
#                            - Added the cancel of the mod's screens, which takes the numpad's 0 with Num Lock on and off
#                            - Took the numpad's 0 frame by frame, so a press a game window cancelled with never cancels again in the next frame
#                            - Watched the numpad's 0 from the start, so its first press of a session counts
#      Paulinchen  2026-10-07: Added the iconset rect, the cut with one ellipsis, white and the depths of the mod's sprites and windows, which the screens share
#                            - Logged every message box shown, with its title and text
#      Paulinchen  2026-10-06: Dropped the wrapped lines the top window kept but never read
#                            - Let a list box say a hint of its own at the bottom, and named how high it lies
#                            - Drew an item being typed into as a text box with its cursor, and the picked item opaque
#                            - Drew buttons at the right end of an item, each a mark outlined in its color or filled with it, the column titles at the heading above, and the one the cursor is on
#      Paulinchen  2026-10-04: Added the message box, a box in the middle of the screen drawn like the list box
#                            - Renamed from mp_ui.rbx
#                            - Drew a list box's item in gold when asked
#                            - Broke the top lines anew only when they changed, and made the list box darker, so the windows behind it show through only a little
#                            - Added the list box, a large box of headings and items drawn like the World overview
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# What the mod's screens and boxes share: breaking a text into lines that fit, the window of lines
# across the top of a screen, the list box and the message box, the style of the flat boxes, the
# motion of a sprite, the color of a player and the confirm box. The text boxes are in
# ui_text_box.rbx.
module MGQ_MpUi
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "ui"

  # Side of an icon of the game's iconset, in pixels.
  ICON_SIZE = 24

  # Icons in a row of the game's iconset.
  ICONS_PER_ROW = 16

  # What ends a text cut to fit.
  ELLIPSIS = "..."

  # Frames the game draws in a second, which a timer counted in frames lapses by.
  FRAMES_PER_SECOND = 60

  # How seconds are written, in the line above the player's head and the waiting box.
  SECONDS_TEXT = "%d s"

  # What a last row says once more lines wait than a box has rows for, see capped.
  MORE_TEXT = "+%d more"

  # Pixels an icon takes in a row with the room after it.
  ICON_STEP = ICON_SIZE + 2

  # The depths of the mod's sprites and windows above the game's, by layer: the arrows at the
  # screen's edges under everything, the lines at the screen's edges, the labels on the map, the
  # bubbles and notices over them, the wheels and what lies above a screen's windows, the World
  # overview, the boxes, the confirm box above every box, and the chat while the player types above
  # everything.
  Z = { :arrows => 190, :lines => 200, :labels => 250, :bubbles => 260, :wheels => 300, :overview => 400, :boxes => 1000, :confirm => 1050, :typing => 1100 }

  # What every flat box of the mod draws with: one background, one plate behind a line on a busy
  # picture, one picked row, one set of text colors, one set of font sizes, one padding, one solid
  # outline and the timings of the fades and slides. The World screen's windows keep the game's
  # window skin; the style is the sprite boxes'.
  module Style
    # Background of every flat box: wheels, list and message box, notices, party box, chat log,
    # overview and confirm box.
    BACK = Color.new(0, 0, 0, 170)

    # Plate behind one line of text that stands on a busy picture, such as the raid bar's.
    PLATE = Color.new(0, 0, 0, 150)

    # Background of the picked row, box or choice.
    PICKED = Color.new(48, 96, 176, 220)

    # Opaque background of a text field being typed into inside a flat box.
    FIELD = Color.new(12, 16, 28)

    # Solid black outline of every text and gauge frame; the game's own outline is half see-through.
    OUTLINE = Color.new(0, 0, 0, 255)

    # Pixels the outline's copies reach around a text, see draw_outlined.
    OUTLINE_REACH = 1

    # Plain text.
    TEXT = Color.new(255, 255, 255)

    # Secondary text: hints, places, system lines, a choice that cannot be taken, a player away.
    DIM = Color.new(176, 176, 176)

    # Fine: online, confirmed, a low ping.
    GOOD = Color.new(128, 255, 128)

    # Middling: a medium ping.
    WARN = Color.new(255, 224, 96)

    # Wrong: a missing mod, a high ping, the formation's cut line, a Raid World's marker.
    BAD = Color.new(255, 96, 96)

    # Stands out: an essential mod, an admin, a featured world.
    GOLD = Color.new(255, 200, 64)

    # Headings, places' headings and key hints.
    HEADING = Color.new(160, 200, 255)

    # The player themself: their own name, the line above their head, their characters in battle.
    OWN = Color.new(255, 225, 110)

    # A party member's name, the same color as GOOD on purpose.
    MEMBER = GOOD

    # Opacity of an icon whose choice cannot be taken.
    DIM_OPACITY = 110

    # Font size of a box's title.
    TITLE_SIZE = 20

    # Font size of text, items and names above heads.
    TEXT_SIZE = 18

    # Font size of notices, party box lines, chat and hints.
    SMALL_SIZE = 16

    # Font size of pings, column titles and places under a name.
    TINY_SIZE = 14

    # Room between a box's edge and its text, and a plate's margin on either side of its text.
    PAD = 6

    # Room between two columns or two tabs of a box.
    GAP = 4

    # What lies between two parts of a hint, such as "Up and down: move" and what closes the box.
    HINT_GAP = "   "

    # The keys that close every screen of the mod, which close_hint names first.
    CLOSE_KEYS = ["Esc", "Numpad 0"]

    # What a close hint ends with.
    CLOSE_TEXT = ": close"

    # Frames a sprite takes to fade in or out.
    FADE_FRAMES = 12

    # Frames a box takes to slide from its offset to its place.
    SLIDE_FRAMES = 8

    # Frames a transient line stays, such as a notice's message: three seconds.
    LINGER_FRAMES = 180

    # Sets a bitmap's font for the next text: its size and color, never bold, which smears the game's
    # pixel font, with the solid outline.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param size [Integer] The font's size.
    # @param color [Color] The text's color.
    def self.use_font(bitmap, size, color)
      font = bitmap.font
      font.size = size
      font.bold = false
      font.color = color
      font.outline = true
      font.out_color = OUTLINE
    end

    # Draws a text in its solid outline: copies in OUTLINE straight above, below and beside it as
    # far as OUTLINE_REACH, the corners left out, then the text in the font's color, which stays
    # as it was.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] The box's left.
    # @param y [Integer] The box's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The box's height.
    # @param text [String] The text.
    # @param align [Integer] 0 for left, 1 for centered, 2 for right, as Bitmap#draw_text takes it.
    def self.draw_outlined(bitmap, x, y, width, height, text, align = 0)
      color = bitmap.font.color
      reach = OUTLINE_REACH
      bitmap.font.color = OUTLINE
      (-reach..reach).each do |dx|
        (-reach..reach).each do |dy|
          next if (dx.zero? && dy.zero?) || (dx.abs == reach && dy.abs == reach)

          bitmap.draw_text(x + dx, y + dy, width, height, text, align)
        end
      end
      bitmap.font.color = color
      bitmap.draw_text(x, y, width, height, text, align)
    end

    # Fills the plate behind a text: as wide as the text with PAD on either side, capped by the
    # box's width, placed in the box by align. Nothing for an empty text. Measures with the
    # bitmap's font as it is set, so use_font comes first.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] The box's left.
    # @param y [Integer] The plate's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The plate's height.
    # @param text [String] The text.
    # @param align [Integer] 0 for left, 1 for centered, 2 for right.
    # @return [Rect] The plate drawn, zero wide for an empty text.
    def self.draw_plate(bitmap, x, y, width, height, text, align = 1)
      return Rect.new(x, y, 0, height) if text.to_s.empty?

      plate_width = [bitmap.text_size(text.to_s).width + 2 * PAD, width].min
      left = align == 0 ? x : align == 2 ? x + width - plate_width : x + (width - plate_width) / 2
      plate = Rect.new(left, y, plate_width, height)
      bitmap.fill_rect(plate, PLATE)
      plate
    end

    # Draws a plated line in one call: draw_plate, then draw_outlined.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] The box's left.
    # @param y [Integer] The line's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The line's height.
    # @param text [String] The text.
    # @param align [Integer] 0 for left, 1 for centered, 2 for right.
    # @return [Rect] The plate drawn.
    def self.draw_plated(bitmap, x, y, width, height, text, align = 1)
      plate = draw_plate(bitmap, x, y, width, height, text, align)
      draw_outlined(bitmap, x, y, width, height, text, align)
      plate
    end

    # Draws a hint whole, centered in its box: a hint names its keys at its end, so it is never
    # cut; one wider than the box is drawn in TINY_SIZE instead, and the game squeezes what still
    # overflows into the box.
    #
    # @param bitmap [Bitmap] The picture.
    # @param x [Integer] The box's left.
    # @param y [Integer] The box's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The box's height.
    # @param hint [String] The hint.
    # @param size [Integer] Its font's size, SMALL_SIZE on a box, TINY_SIZE under a wheel.
    # @param color [Color] Its color, DIM on a box, HEADING under a wheel.
    def self.draw_hint(bitmap, x, y, width, height, hint, size = SMALL_SIZE, color = DIM)
      use_font(bitmap, size, color)
      use_font(bitmap, TINY_SIZE, color) if size > TINY_SIZE && bitmap.text_size(hint).width > width
      bitmap.draw_text(x, y, width, height, hint, 1)
    end

    # Writes the hint that names what closes a screen, in one wording and order everywhere: the
    # keys every screen closes with, then what else closes this one.
    #
    # @param also [Array<String>] What else closes it, such as a hotkey's label or "a click outside".
    # @return [String] Such as "Esc, Numpad 0 or F11: close", "Esc or Numpad 0: close" for none.
    def self.close_hint(*also)
      keys = CLOSE_KEYS + also.map { |key| key.to_s }
      "#{keys[0..-2].join(', ')} or #{keys[-1]}#{CLOSE_TEXT}"
    end

    # Fades a text's color for a line about to go: its alpha falls over the last FADE_FRAMES frames.
    #
    # @param color [Color] The color at its full strength.
    # @param frames [Integer] Frames the line has left; FADE_FRAMES or more leave the color as it is.
    # @return [Color] The color, the same object while nothing fades.
    def self.faded(color, frames)
      return color if frames >= FADE_FRAMES

      alpha = color.alpha || Motion::OPAQUE
      Color.new(color.red, color.green, color.blue, alpha * [frames, 0].max / FADE_FRAMES)
    end
  end

  @top_room = 0

  # Windows' codes of the numpad's 0, the game's cancel key, with Num Lock on and off; the second
  # is also the Insert key's.
  NUMPAD_CANCEL_KEYS = [0x60, 0x2D]
  MGQ_Multiplayer::Key.watch(*NUMPAD_CANCEL_KEYS)

  # Reports whether the numpad's 0 went down in this frame, with Num Lock on or off. A text box asks
  # it instead of cancel?, since the game's cancel button is X too, a letter.
  #
  # With Num Lock on it is the game's cancel button as well, so a press a game window took must not
  # count again in the next frame, after the window's cancel opened another screen.
  #
  # @return [Boolean] Whether it did.
  def self.numpad_cancel?
    NUMPAD_CANCEL_KEYS.map { |code| MGQ_Multiplayer::Key.triggered?(code) }.any?
  end

  # Reports whether cancel went down on a screen of the mod: the game's cancel button, past the
  # capture, or the numpad's 0, which the game takes only with Num Lock on.
  #
  # @return [Boolean] Whether it did.
  def self.cancel?
    MGQ_Multiplayer::Capture.trigger?(:B) | numpad_cancel?
  end

  # Finds an icon in the game's iconset.
  #
  # @param icon [Integer] The icon's index.
  # @return [Rect] Where the icon lies in the iconset.
  def self.icon_rect(icon)
    Rect.new(icon % ICONS_PER_ROW * ICON_SIZE, icon / ICONS_PER_ROW * ICON_SIZE, ICON_SIZE, ICON_SIZE)
  end

  # Draws an icon of the game's iconset on a bitmap, scaled to a square of any side, which the
  # labels, boxes and wheels share.
  #
  # @param bitmap [Bitmap] The bitmap.
  # @param icon [Integer, nil] The icon's index, nil for none.
  # @param x [Integer] The icon's left.
  # @param y [Integer] The icon's top.
  # @param side [Integer] The square's side, the iconset's own by default.
  # @param opacity [Integer] How opaque, Style::DIM_OPACITY for a choice that cannot be taken.
  def self.draw_icon(bitmap, icon, x, y, side = ICON_SIZE, opacity = Motion::OPAQUE)
    return unless icon

    bitmap.stretch_blt(Rect.new(x, y, side, side), Cache.system("Iconset"), icon_rect(icon), opacity)
  end

  # Splits a list into the rows a box shows and how many more wait, so the box never grows past
  # its rows, the last of which then says how many more there are (MORE_TEXT).
  #
  # @param list [Array] The lines.
  # @param rows [Integer] The rows the box has.
  # @return [Array] The lines shown, and how many more there are, 0 when all fit.
  def self.capped(list, rows)
    return [list, 0] if list.size <= rows

    [list.first(rows - 1), list.size - rows + 1]
  end

  # Tells the pixels at the top of the map's screen a strip of the mod takes, such as the raid
  # boss's bar, which the boxes there move down by.
  #
  # @return [Integer] The pixels, 0 while none shows.
  def self.top_room
    @top_room
  end

  # Sets the pixels at the top of the map's screen a strip of the mod takes, see top_room.
  #
  # @param pixels [Integer] The pixels.
  def self.top_room=(pixels)
    @top_room = pixels.to_i
  end

  # Keeps a value between two bounds.
  #
  # @param value [Numeric] The value.
  # @param low [Numeric] The lower bound.
  # @param high [Numeric] The upper bound.
  # @return [Numeric] The value, or the bound it passed.
  def self.within(value, low, high)
    [[value, low].max, high].min
  end

  # Writes a whole number with its thousands grouped by commas, unlike the game's own number
  # helpers, which shorten large numbers.
  #
  # @param number [Numeric] The number.
  # @return [String] Such as "3,412,880".
  def self.grouped(number)
    whole = number.to_i
    digits = whole.abs.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
    whole < 0 ? "-#{digits}" : digits
  end

  # Cuts a text at its end until it fits a width with ELLIPSIS and what follows it.
  #
  # @param measure [Bitmap, Window_Base] What measures a text with the font it is drawn in.
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @param tail [String] What follows the text and stays whole, such as a count or a floor.
  # @return [String] The text with the tail when they fit, else the text's start, ELLIPSIS and the tail.
  def self.cut(measure, text, width, tail = "")
    text = text.to_s
    return "#{text}#{tail}" if measure.text_size("#{text}#{tail}").width <= width

    head = text
    head = head[0...-1].rstrip while !head.empty? && measure.text_size("#{head}#{ELLIPSIS}#{tail}").width > width
    "#{head}#{ELLIPSIS}#{tail}"
  end

  # Breaks a text into lines that fit a width, at its spaces, and inside a word longer than the
  # width.
  #
  # @param measure [Bitmap, Window_Base] What measures a text with the font the lines are drawn in.
  # @param text [String] The text.
  # @param width [Integer] The width in pixels.
  # @return [Array<String>] The lines.
  def self.wrap(measure, text, width)
    lines = [""]
    text.split(" ").each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if measure.text_size(candidate).width <= width
        lines[-1] = candidate
        next
      end

      lines.push("") unless lines.last.empty?
      word.each_char do |char|
        lines.push("") if measure.text_size(lines.last + char).width > width && !lines.last.empty?
        lines[-1] += char
      end
    end
    lines
  end

  # The motion of one sprite: a fade in and out of its opacity over Style::FADE_FRAMES and a slide
  # to its resting place over Style::SLIDE_FRAMES, in even steps. Whoever owns the sprite owns the
  # motion, calls update once a frame where it updates the sprite, and sets neither visible nor
  # opacity itself any more.
  class Motion
    # Full opacity.
    OPAQUE = 255

    # Takes a sprite, whose x and y now are its resting place, as hidden until show.
    #
    # @param sprite [Sprite] The sprite.
    def initialize(sprite)
      @sprite = sprite
      @rest_x = sprite.x.to_i
      @rest_y = sprite.y.to_i
      @placed = false
      @offset_x = @offset_y = 0.0
      @step_x = @step_y = 0.0
      @opacity = 0.0
      @target = 0
      sprite.visible = false
      sprite.opacity = 0
    end

    # Makes a hidden sprite visible at an offset from its resting place with opacity 0, heading for
    # the place and full opacity. From a fade out it only turns the opacity back: the offset and
    # the sprite's place stay, so nothing jumps. Nothing while shown or fading in, so an owner may
    # call it every frame it has something to show.
    #
    # @param dx [Integer] Pixels left (negative) or right of the place to start from, 0 for a fade alone.
    # @param dy [Integer] Pixels above (negative) or below the place to start from.
    def show(dx = 0, dy = 0)
      return if shown? || @sprite.disposed?

      if hidden?
        @offset_x = dx.to_f
        @offset_y = dy.to_f
        @step_x = @offset_x / Style::SLIDE_FRAMES
        @step_y = @offset_y / Style::SLIDE_FRAMES
        @opacity = 0.0
        @sprite.visible = true
        write
      end
      @target = OPAQUE
    end

    # Heads for opacity 0; a slide still running keeps running. Once at 0 the sprite is made
    # invisible. Nothing while hidden or fading out. The owner keeps the sprite's last picture until
    # hidden?.
    def hide
      @target = 0
    end

    # Sets the resting place without a slide, for a box that follows MGQ_MpUi.top_room every
    # frame. The sprite keeps whatever offset it still has.
    #
    # @param x [Integer] The place's x.
    # @param y [Integer] The place's y.
    def place(x, y)
      @rest_x = x.to_i
      @rest_y = y.to_i
      @placed = true
      write
    end

    # Sets a new resting place and slides there from where the sprite stands now. The first call
    # on a motion never placed places without a slide.
    #
    # @param x [Integer] The place's x.
    # @param y [Integer] The place's y.
    def slide_to(x, y)
      return place(x, y) unless @placed

      @offset_x = (@rest_x + @offset_x) - x.to_i
      @offset_y = (@rest_y + @offset_y) - y.to_i
      @step_x = @offset_x / Style::SLIDE_FRAMES
      @step_y = @offset_y / Style::SLIDE_FRAMES
      @rest_x = x.to_i
      @rest_y = y.to_i
      write
    end

    # Moves one frame: the opacity by OPAQUE / Style::FADE_FRAMES towards its target, the offset
    # by its start / Style::SLIDE_FRAMES towards 0, and writes them to the sprite, which turns
    # invisible once a fade out arrived. Nothing on a disposed sprite.
    #
    # @return [Boolean] Whether it still moves after this frame.
    def update
      return false if @sprite.disposed?

      @opacity = Motion.step_towards(@opacity, @target, OPAQUE.to_f / Style::FADE_FRAMES)
      @offset_x = Motion.step_towards(@offset_x, 0.0, @step_x.abs)
      @offset_y = Motion.step_towards(@offset_y, 0.0, @step_y.abs)
      write
      @sprite.visible = false if hidden?
      moving?
    end

    # Reports whether the opacity or the offset still move.
    #
    # @return [Boolean] Whether one does.
    def moving?
      @opacity != @target || @offset_x != 0.0 || @offset_y != 0.0
    end

    # Reports whether the sprite is shown or fading in.
    #
    # @return [Boolean] Whether its target opacity is full.
    def shown?
      @target == OPAQUE
    end

    # Reports whether the sprite is invisible: a fade out finished, or never shown.
    #
    # @return [Boolean] Whether it is.
    def hidden?
      @target == 0 && @opacity <= 0.0
    end

    # Moves a value one step towards a target, landing on the target within the last step, which
    # a sprite with a slide of its own shares, such as the raid bar's strip.
    #
    # @param value [Float] The value.
    # @param target [Float] The target.
    # @param step [Float] The step's size, 0 or more.
    # @return [Float] The value moved.
    def self.step_towards(value, target, step)
      return target if (target - value).abs <= step

      value < target ? value + step : value - step
    end

    # Writes the sprite's place and opacity; nothing on a disposed sprite, which raises on a write.
    def write
      return if @sprite.disposed?

      @sprite.x = @rest_x + @offset_x.round
      @sprite.y = @rest_y + @offset_y.round
      @sprite.opacity = @opacity.round
    end
  end

  # The color a player is named in everywhere: Style::OWN for the player themself, Style::MEMBER
  # for a party member, and for anyone else one of eight colors by a stable hash of their id, so a
  # player keeps their color across maps and sessions.
  module PlayerColor
    # Eight colors that read on a dark plate and, outlined, over a bright map: no green, yellow,
    # red, grey or white, which mean party, self, bad, dim and plain.
    PALETTE = [
      Color.new(120, 200, 255),
      Color.new(255, 150, 60),
      Color.new(255, 140, 190),
      Color.new(190, 130, 255),
      Color.new(80, 220, 200),
      Color.new(255, 190, 150),
      Color.new(170, 170, 255),
      Color.new(210, 170, 120),
    ]

    # The palette's names in its order, for the log and the tests.
    NAMES = %w[sky orange pink violet teal peach lavender tan]

    # What a player's own color and a party member's are called in the log.
    OWN_NAME = "own"
    MEMBER_NAME = "member"

    # What an unknown player's color is called in the log.
    PLAIN_NAME = "plain"

    # Multiplier and modulus of an id's hash, see index.
    HASH_STEP = 31
    HASH_MOD = 65_521

    # Hashes a player's id to a place in PALETTE, the same in every session and game: a byte sum,
    # since String#hash differs per process from Ruby 1.9 on.
    #
    # @param id [String] The id.
    # @return [Integer] 0 to 7.
    def self.index(id)
      id.to_s.each_byte.inject(0) { |sum, byte| (sum * HASH_STEP + byte) % HASH_MOD } % PALETTE.size
    end

    # Finds a player's id.
    #
    # @param who [MGQ_MpOverworldSync::Peers::Peer, Hash, String, Symbol] A peer, a state hash
    #   with "id", an id, or :me.
    # @return [String] The id, "" for none.
    def self.id_of(who)
      if who == :me
        defined?(MGQ_MpOverworldSync::Me) ? MGQ_MpOverworldSync::Me.id.to_s : ""
      elsif who.is_a?(String)
        who
      elsif who.is_a?(Hash)
        who["id"].to_s
      elsif who.respond_to?(:state) && who.state.is_a?(Hash)
        who.state["id"].to_s
      else
        ""
      end
    rescue
      ""
    end

    # Picks a player's color: Style::OWN for the player themself, Style::MEMBER for a party
    # member, else the palette's by their id; Style::TEXT for one without an id or one it cannot
    # read.
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @param member [Boolean, nil] Whether they are in the player's party; nil derives it from a
    #   peer's member, a state hash through MGQ_MpCoop::Party.member? once coop loaded, false for
    #   an id.
    # @param own [Boolean, nil] Whether they are the player; nil derives it from :me, or an id equal
    #   to MGQ_MpOverworldSync::Me.id once overworld_sync loaded.
    # @return [Color] The color.
    def self.of(who, member = nil, own = nil)
      from(pick(who, member, own), Style::OWN, Style::MEMBER, Style::TEXT, PALETTE)
    end

    # Names a player's color for the log, such as "sky", "own" or "member".
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @param member [Boolean, nil] See of.
    # @param own [Boolean, nil] See of.
    # @return [String] The name.
    def self.label(who, member = nil, own = nil)
      from(pick(who, member, own), OWN_NAME, MEMBER_NAME, PLAIN_NAME, NAMES)
    end

    # Picks a player's place among the colors, which of and label read in their own set.
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @param member [Boolean, nil] See of.
    # @param own [Boolean, nil] See of.
    # @return [Symbol, Integer, nil] :own for the player themself, :member for a party member, a
    #   place in the palette for anyone else, nil for one without an id or one it cannot read.
    def self.pick(who, member = nil, own = nil)
      return :own if own.nil? ? own?(who) : own
      return :member if member.nil? ? member?(who) : member

      id = id_of(who)
      id.empty? ? nil : index(id)
    rescue
      nil
    end

    # Reads a place picked in one set of values.
    #
    # @param place [Symbol, Integer, nil] The place, see pick.
    # @param own [Object] The value for the player themself.
    # @param member [Object] The value for a party member.
    # @param plain [Object] The value for a player without a place.
    # @param palette [Array] The values by their place in PALETTE.
    # @return [Object] The value.
    def self.from(place, own, member, plain, palette)
      case place
      when :own then own
      when :member then member
      when nil then plain
      else palette[place]
      end
    end

    # Reports whether a player is the player themself.
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @return [Boolean] Whether they are.
    def self.own?(who)
      return true if who == :me
      return false unless defined?(MGQ_MpOverworldSync::Me)

      id = id_of(who)
      !id.empty? && id == MGQ_MpOverworldSync::Me.id.to_s
    end

    # Reports whether a player is in the player's party.
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @return [Boolean] Whether they are.
    def self.member?(who)
      return who.member ? true : false if who.respond_to?(:member)
      return false unless who.is_a?(Hash) && defined?(MGQ_MpCoop::Party)

      MGQ_MpCoop::Party.member?(who) ? true : false
    end
  end

  # A yes or no question over any scene: the map, a menu, the trade screen, the World overview.
  # One box at a time; it takes the buttons under it and the hotkeys (see MGQ_MpHotkeys.pressed?)
  # while open.
  #
  # An answer finishes in the tick after the one that read it, since a press reads as pressed until
  # the next Input.update and would otherwise reach whatever lies under the box in the same frame.
  module Confirm
    # The hint under the choices: the yes label and its hotkey, the no label with its hotkey and
    # the keys that cancel, and confirm, which takes the choice picked.
    HINT = ["%s: %s", "%s: %s, #{Style::CLOSE_KEYS.join(' or ')}", "Enter: the picked one"].join(Style::HINT_GAP)

    # The owner the box takes the buttons as.
    SCREEN = :confirm

    # Why a box was answered no from outside unless the caller says.
    CLOSED_REASON = "closed from outside"

    # Why a box was answered no once the scene it opened in ended.
    SCENE_CHANGED_REASON = "the scene changed"

    # Why a box was answered no once its tick failed.
    TICK_FAILED_REASON = "the tick failed"

    @open = false
    @answer = nil
    @sprite = nil

    # Opens the box. Refused while one is open, also in the tick after its answer, or while the
    # question is empty.
    #
    # @param question [String] The question, wrapped to the box's width.
    # @param choices [Array<String>] The yes choice's label, such as "Leave", and the no choice's,
    #   such as "Stay", which starts picked.
    # @yieldparam answer [Boolean] true for yes, false for no, for a close from outside and for a
    #   scene change while open. Called once, in the tick after the one that answered, after the
    #   buttons are given back.
    # @return [Boolean] Whether it opened.
    def self.ask(question, choices, &answer)
      if open?
        MGQ_MpUi.log("confirm box refused: one is open (#{@question})")
        return false
      end
      if question.to_s.empty?
        MGQ_MpUi.log("confirm box refused: the question is empty")
        return false
      end

      @open = true
      @answer = nil
      @question = question.to_s
      @yes = choices[0].to_s
      @no = choices[1].to_s
      @block = answer
      @scene = SceneManager.scene
      @picked = false
      @asked_at = Graphics.frame_count
      MGQ_Multiplayer::Key.watch(MGQ_MpHotkeys.code(:accept), MGQ_MpHotkeys.code(:decline))
      MGQ_Multiplayer::Capture.start(SCREEN)
      @sprite = Sprite_MpConfirmBox.new
      @sprite.show(@question, @yes, @no, @picked)
      MGQ_MpUi.log("confirm box: #{@question} (#{@yes} / #{@no})")
      true
    rescue => e
      MGQ_MpUi.log("confirm box could not open: #{e.class}: #{e.message}")
      drop_sprite
      @open = false
      MGQ_Multiplayer::Capture.stop(SCREEN)
      false
    end

    # Reports whether a box is open: from ask until the tick that calls its block.
    #
    # @return [Boolean] Whether one is.
    def self.open?
      @open
    end

    # Answers no without the player: the box disappears now, the block runs in the next tick.
    # Nothing while no box is open or one is answered already.
    #
    # @param reason [String] Why, for the log.
    def self.close(reason = CLOSED_REASON)
      decide(false, reason, false) if open? && @answer.nil?
    end

    # Answers no and finishes at once as a scene starts, since a scene whose start waits in a loop
    # of its own, such as a co-op battle's, would never tick a box left open; a start reads no key,
    # so nothing under the box takes the press that answered. Called after every scene's start.
    def self.leave_scene
      return unless open?

      decide(false, SCENE_CHANGED_REASON, false) if @answer.nil?
      finish
    end

    # Finishes an answer given in the tick before, else reads the keys: the scene ending answers
    # no, none while the player types into a text box, none in the frame of ask. Called after
    # every scene's update. A tick that fails answers no, so the box never holds the buttons and
    # the hotkeys for good.
    def self.tick
      return unless open?
      return finish if @answer
      return decide(false, SCENE_CHANGED_REASON, false) unless SceneManager.scene.equal?(@scene)
      return if $mgq_text_input || Graphics.frame_count == @asked_at

      read_keys
    rescue => e
      MGQ_MpUi.log_once(:confirm_tick, "confirm box tick failed: #{e.class}: #{e.message}")
      @answer ||= [false, TICK_FAILED_REASON]
      drop_sprite
    end

    # Reads the keys, all frame-level: the accept hotkey answers yes, the decline hotkey and
    # cancel no, confirm takes the picked choice, left and right move the pick.
    def self.read_keys
      if MGQ_Multiplayer::Key.triggered?(MGQ_MpHotkeys.code(:accept))
        decide(true, "the #{MGQ_MpHotkeys.label(:accept)} hotkey")
      elsif MGQ_Multiplayer::Key.triggered?(MGQ_MpHotkeys.code(:decline))
        decide(false, "the #{MGQ_MpHotkeys.label(:decline)} hotkey")
      elsif MGQ_MpUi.cancel?
        decide(false, "cancel")
      elsif MGQ_Multiplayer::Capture.trigger?(:C)
        decide(@picked, "confirm")
      elsif MGQ_Multiplayer::Capture.repeat?(:LEFT) | MGQ_Multiplayer::Capture.repeat?(:RIGHT)
        @picked = !@picked
        Sound.play_cursor
        @sprite.repick(@picked)
      end
    end

    # Keeps an answer for the next tick, plays its sound and takes the box off the screen.
    #
    # @param answer [Boolean] true for yes.
    # @param reason [String] What answered, for the log.
    # @param by_player [Boolean] Whether the player answered, which plays the choice's sound.
    def self.decide(answer, reason, by_player = true)
      @answer = [answer, reason]
      (answer ? Sound.play_ok : Sound.play_cancel) if by_player
      MGQ_MpUi.log("confirm box answered #{answer ? @yes : @no} (#{reason}): #{@question}")
      drop_sprite
    end

    # Takes the box off the screen.
    def self.drop_sprite
      @sprite.dispose if @sprite && !@sprite.disposed?
      @sprite = nil
    end

    # Hands the answer kept to the block: clears the box, gives the buttons back, then calls the
    # block once.
    def self.finish
      answer = @answer[0]
      block = @block
      @open = false
      @answer = @block = @question = @yes = @no = @scene = nil
      MGQ_Multiplayer::Capture.stop(SCREEN)
      block.call(answer) if block
    rescue => e
      MGQ_MpUi.log("the confirm box's answer failed: #{e.class}: #{e.message}")
    end
  end
end

# The lines across the top of a screen of the mod, such as the world screen's.
class Window_MpInfo < Window_Base
  # Lines the window has room for unless told otherwise.
  LINES = 3

  # Creates the window across the top of the screen, empty.
  #
  # @param rows [Integer] The lines it has room for.
  def initialize(rows = LINES)
    super(0, 0, Graphics.width, fitting_height(rows))
    @rows = rows
  end

  # Draws the lines, if they changed, wrapping long ones.
  #
  # @param lines [Array<String, nil>] The lines, nil ones left out.
  def show(lines)
    return if lines == @given

    @given = lines.dup
    wrapped = lines.compact.map { |line| MGQ_MpUi.wrap(self, line, contents_width) }.flatten
    contents.clear
    wrapped.first(@rows).each_with_index do |line, index|
      draw_text(0, index * line_height, contents_width, line_height, line)
    end
  end
end

# A large box over a screen that lists lines under a title, as the World overview does: headings
# and items, one of which is picked, with a hint at the bottom. Whoever opens it moves the pick and
# closes it; the box only draws.
class Sprite_MpListBox < Sprite
  # Room between the box and either side of the screen.
  SIDE = 40

  # Room between the box and the top of the screen.
  TOP = 32

  # Room between the box and the bottom of the screen.
  BOTTOM = 44

  # How far above the screen's windows the box lies.
  Z = MGQ_MpUi::Z[:boxes]

  # Height of one line of the list.
  ROW = 24

  # Height of the title.
  TITLE = 30

  # Height of the hint at the bottom.
  HINT_HEIGHT = 22

  # Room between the last line in sight and the hint.
  LIST_ROOM = 8

  # Room between the box's side edges and its title, its headings and its hint.
  EDGE = 10

  # Left edge of an item's text.
  ITEM_LEFT = 24

  # Room between an item's text and what lies right of it.
  ITEM_GAP = 16

  # Width kept at the right of an item for what it says there.
  RIGHT_WIDTH = 120

  # Side of a button at the right end of an item.
  BUTTON_SIZE = 18

  # Width of a column of buttons, wide enough for the column's title above it.
  BUTTON_COLUMN = 70

  # Room between the last column of buttons and the box's edge.
  BUTTON_MARGIN = 6

  # Width of the label in front of a text box in an item.
  TYPING_LABEL = 60

  # The colors a button may have, by name.
  BUTTON_COLORS = { :red => Color.new(230, 50, 50), :orange => Color.new(255, 150, 20) }

  # Pixels the title keeps from the box's top and bottom edges of its row.
  TITLE_INSET = 2

  # Pixels the picked row's plate keeps from the box's side edges.
  PICK_INSET = 4

  # What the hint says unless the list says another.
  HINT = ["Up and down: move", MGQ_MpUi::Style.close_hint("a click outside")].join(MGQ_MpUi::Style::HINT_GAP)

  # Tells where the box sits on the screen: SIDE from either side, TOP from the top and BOTTOM from
  # the bottom, read from the screen once it is first asked.
  #
  # @return [Rect] The box.
  def self.box
    @box ||= Rect.new(SIDE, TOP, Graphics.width - 2 * SIDE, Graphics.height - TOP - BOTTOM)
  end

  # Tells how many lines of the list the box shows at once.
  #
  # @return [Integer] The lines.
  def self.list_rows
    (box.height - TITLE - HINT_HEIGHT - LIST_ROOM) / ROW
  end

  # What the box lists.
  #
  # @!attribute title [String] The title at the top left.
  # @!attribute note [String, nil] What the top right says.
  # @!attribute lines [Array<Array>] [:head, text, titles] for a heading, titles nil or those of the button columns below it; [:item, text, color, right, buttons] for an item: color is :plain, :good, :gold, :bad or :grey, right what its right end says or nil, buttons nil or each button's mark, color (:red or :orange) and whether it is on. An item being typed into adds [editor, text, cursor, cursor shown], its text the box's label.
  # @!attribute selected [Integer, nil] The line of the item picked, nil without items.
  # @!attribute scroll [Integer] The first line in sight.
  # @!attribute hint [String, nil] What the bottom says, nil for HINT.
  # @!attribute column [Integer, nil] The button of the picked item the cursor is on, from 1; nil or 0 for the item itself.
  View = Struct.new(:title, :note, :lines, :selected, :scroll, :hint, :column) do
    # Makes a list with its first item picked.
    #
    # @param title [String] The title.
    # @param note [String, nil] What the top right says.
    # @param lines [Array<Array>] The lines.
    # @param hint [String, nil] What the bottom says, nil for HINT.
    # @return [View] The list.
    def self.of(title, note, lines, hint = nil)
      new(title, note, lines, (0...lines.size).find { |line| lines[line][0] == :item }, 0, hint)
    end

    # Lists the lines that are items.
    #
    # @return [Array<Integer>] The lines.
    def items
      (0...lines.size).select { |line| lines[line][0] == :item }
    end

    # Picks the item a number of items further, stopping at the first and the last.
    #
    # @param step [Integer] 1 for the next, -1 for the one before.
    def move(step)
      at = items.index(selected)
      pick(items[[[at + step, 0].max, items.size - 1].min]) if at
    end

    # Picks an item and scrolls it into sight, with the heading right above it.
    #
    # @param line [Integer] The item's line.
    def pick(line)
      self.selected = line
      top = line > 0 && lines[line - 1][0] == :head ? line - 1 : line
      rows = Sprite_MpListBox.list_rows
      self.scroll = top if top < scroll
      self.scroll = line - rows + 1 if line >= scroll + rows
    end
  end

  # Creates the box, hidden, above every window.
  def initialize
    super(nil)
    box = self.class.box
    self.bitmap = Bitmap.new(box.width, box.height)
    self.x = box.x
    self.y = box.y
    self.z = Z
    @motion = MGQ_MpUi::Motion.new(self)
    @shown = nil
  end

  # Reports whether a point of the screen lies in the box.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @return [Boolean] Whether it does.
  def self.inside?(x, y)
    x >= box.x && x < box.x + box.width && y >= box.y && y < box.y + box.height
  end

  # Finds the button of an item under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param count [Integer] How many buttons the item has.
  # @return [Integer, nil] The button, from 1 at the left; nil outside them.
  def self.button_at(x, count)
    (1..count).find do |button|
      left = box.x + column_left(button, count)
      x >= left && x < left + BUTTON_COLUMN
    end
  end

  # Tells where a column of buttons starts, inside the box.
  #
  # @param button [Integer] The column, from 1 at the left.
  # @param count [Integer] How many columns there are.
  # @return [Integer] Its left edge.
  def self.column_left(button, count)
    box.width - BUTTON_MARGIN - (count - button + 1) * BUTTON_COLUMN
  end

  # Tells where a button of an item starts, inside the box: in the middle of its column.
  #
  # @param button [Integer] The button, from 1 at the left.
  # @param count [Integer] How many buttons the item has.
  # @return [Integer] Its left edge.
  def self.button_left(button, count)
    column_left(button, count) + (BUTTON_COLUMN - BUTTON_SIZE) / 2
  end

  # Finds the line of the list under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [View] What the box lists.
  # @return [Integer, nil] The line, nil outside the list.
  def self.line_at(x, y, view)
    return nil unless inside?(x, y) && y >= box.y + TITLE

    row = (y - box.y - TITLE) / ROW
    line = view.scroll + row
    row < list_rows && line < view.lines.size ? line : nil
  end

  # Shows a list, fading it in, drawing it if it changed.
  #
  # @param view [View] What the box lists.
  def show(view)
    @motion.show
    drawn = view.to_a
    return if drawn == @shown

    @shown = drawn.map { |part| part.is_a?(Array) ? part.dup : part }
    draw(view)
  end

  # Fades the box out, keeping its picture until it is gone.
  def hide
    @motion.hide
    @shown = nil
  end

  # Moves the fade a frame on. Called every frame by the screen that owns the box.
  def update
    super
    @motion.update
  end

  # Draws the whole box: the title with its note at the right, the lines in sight, the hint.
  #
  # @param view [View] What the box lists.
  def draw(view)
    style = MGQ_MpUi::Style
    width = bitmap.width
    bitmap.clear
    bitmap.fill_rect(bitmap.rect, style::BACK)
    style.use_font(bitmap, style::TITLE_SIZE, style::GOOD)
    note_width = view.note ? bitmap.text_size(view.note).width + style::PAD : 0
    bitmap.draw_text(EDGE, TITLE_INSET, width - 2 * EDGE, TITLE - 2 * TITLE_INSET, view.note, 2) if view.note
    style.use_font(bitmap, style::TITLE_SIZE, style::TEXT)
    bitmap.draw_text(EDGE, TITLE_INSET, width - 2 * EDGE, TITLE - 2 * TITLE_INSET, MGQ_MpUi.cut(bitmap, view.title, width - 2 * EDGE - note_width))
    lines = view.lines[view.scroll, self.class.list_rows] || []
    lines.each_with_index { |line, index| draw_line(line, TITLE + index * ROW, view.scroll + index == view.selected, view.column.to_i) }
    style.draw_hint(bitmap, EDGE, bitmap.height - HINT_HEIGHT, width - 2 * EDGE, HINT_HEIGHT, view.hint || HINT)
  end

  # Draws one line of the list: a heading, with the titles of the button columns below it, or an
  # item, its text cut to the room before what lies at its right.
  #
  # @param line [Array] The line, see View.
  # @param y [Integer] The line's top.
  # @param picked [Boolean] Whether it is the item picked.
  # @param column [Integer] The button the cursor is on while it is picked, 0 for the item itself.
  def draw_line(line, y, picked, column = 0)
    kind, text, color, right, buttons, typing = line
    style = MGQ_MpUi::Style
    width = bitmap.width

    if kind == :head
      draw_heading(text, color, y)
      return
    end

    bitmap.fill_rect(PICK_INSET, y, width - 2 * PICK_INSET, ROW, style::PICKED) if picked
    style.use_font(bitmap, style::TEXT_SIZE, { :good => style::GOOD, :gold => style::GOLD, :bad => style::BAD, :grey => style::DIM }[color] || style::TEXT)
    return draw_typing(text, typing[0], y) if typing

    buttons_width = buttons ? buttons.size * BUTTON_COLUMN + BUTTON_MARGIN : 0
    room = width - ITEM_LEFT - ITEM_GAP - (right ? RIGHT_WIDTH : 0) - buttons_width
    bitmap.draw_text(ITEM_LEFT, y, room, ROW, MGQ_MpUi.cut(bitmap, text, room))

    if right
      bitmap.font.size = style::SMALL_SIZE
      bitmap.draw_text(width - RIGHT_WIDTH - EDGE - buttons_width, y, RIGHT_WIDTH, ROW, MGQ_MpUi.cut(bitmap, right, RIGHT_WIDTH), 2)
    end

    (buttons || []).each_with_index do |(glyph, tint, on), index|
      x = self.class.button_left(index + 1, buttons.size)
      draw_button(glyph, BUTTON_COLORS[tint] || style::DIM, on, x, y + (ROW - BUTTON_SIZE) / 2, picked && column == index + 1)
    end
  end

  # Draws an item being typed into: its label, then a text box with the text and the cursor.
  #
  # @param label [String] What the text is for.
  # @param editor [MGQ_MpUi::TextEdit] The text box's editor.
  # @param y [Integer] The line's top.
  def draw_typing(label, editor, y)
    style = MGQ_MpUi::Style
    bitmap.draw_text(ITEM_LEFT, y, TYPING_LABEL, ROW, MGQ_MpUi.cut(bitmap, label, TYPING_LABEL))
    box = Rect.new(ITEM_LEFT + TYPING_LABEL, y + 2, bitmap.width - ITEM_LEFT - TYPING_LABEL - ITEM_GAP, ROW - 4)
    bitmap.fill_rect(box, style::FIELD)
    bitmap.font.color = style::TEXT
    MGQ_MpUi::TextBox.draw_line(bitmap, Rect.new(box.x + 4, y, box.width - 8, ROW), editor)
  end

  # Draws a heading, and the titles of the button columns of the items below it at its right.
  #
  # @param text [String] The heading.
  # @param titles [Array<String>, nil] The columns' titles, from the left; nil for none.
  # @param y [Integer] The line's top.
  def draw_heading(text, titles, y)
    style = MGQ_MpUi::Style
    style.use_font(bitmap, style::TEXT_SIZE, style::HEADING)
    bitmap.draw_text(EDGE, y, bitmap.width - 2 * EDGE, ROW, MGQ_MpUi.cut(bitmap, text, bitmap.width - 2 * EDGE))
    bitmap.font.size = style::TINY_SIZE

    (titles || []).each_with_index do |title, index|
      left = self.class.column_left(index + 1, titles.size)
      bitmap.draw_text(left, y, BUTTON_COLUMN, ROW, title, 1)
    end
  end

  # Draws a button: its mark in a square outlined in its color while off, filled while on, and
  # framed in the text's color while the cursor is on it.
  #
  # @param glyph [String] Its mark, such as "!".
  # @param color [Color] Its color.
  # @param on [Boolean] Whether it is on.
  # @param x [Integer] Its left edge.
  # @param y [Integer] Its top edge.
  # @param focused [Boolean] Whether the cursor is on it.
  def draw_button(glyph, color, on, x, y, focused)
    style = MGQ_MpUi::Style
    draw_frame(x - 3, y - 3, BUTTON_SIZE + 6, style::TEXT) if focused

    if on
      bitmap.fill_rect(x, y, BUTTON_SIZE, BUTTON_SIZE, color)
    else
      draw_frame(x, y, BUTTON_SIZE, color)
      draw_frame(x + 1, y + 1, BUTTON_SIZE - 2, color)
    end

    style.use_font(bitmap, style::SMALL_SIZE, on ? style::TEXT : color)
    bitmap.draw_text(x, y, BUTTON_SIZE, BUTTON_SIZE, glyph, 1)
  end

  # Draws a square frame, one pixel wide.
  #
  # @param x [Integer] Its left edge.
  # @param y [Integer] Its top edge.
  # @param size [Integer] Its side.
  # @param color [Color] Its color.
  def draw_frame(x, y, size, color)
    bitmap.fill_rect(x, y, size, 1, color)
    bitmap.fill_rect(x, y + size - 1, size, 1, color)
    bitmap.fill_rect(x, y, 1, size, color)
    bitmap.fill_rect(x + size - 1, y, 1, size, color)
  end
  # Frees the box's picture.
  def dispose
    bitmap.dispose
    super
  end
end

# A box in the middle of the screen that tells the player something, drawn like the list box: a
# title, the text broken into lines that fit, and a hint at the bottom. Whoever shows it closes it.
class Sprite_MpMessageBox < Sprite
  # Room between the box and either side of the screen.
  SIDE = 80

  # Room between the box's edges and its text.
  PADDING = 2 * MGQ_MpUi::Style::PAD

  # Height of one line of the text.
  ROW = 24

  # Creates the box, hidden, above every window.
  def initialize
    super(nil)
    self.z = MGQ_MpUi::Z[:boxes]
    self.visible = false
  end

  # Shows a message in the middle of the screen, as wide as the screen leaves between SIDE on
  # either side and as high as its lines need.
  #
  # @param title [String] The title at the top.
  # @param text [String] The text.
  # @param hint [String] What the hint at the bottom says.
  def show(title, text, hint)
    style = MGQ_MpUi::Style
    width = Graphics.width - 2 * SIDE
    measure = Bitmap.new(1, 1)
    style.use_font(measure, style::TEXT_SIZE, style::TEXT)
    lines = MGQ_MpUi.wrap(measure, text, width - 2 * PADDING)
    measure.dispose

    height = Sprite_MpListBox::TITLE + lines.size * ROW + Sprite_MpListBox::HINT_HEIGHT + PADDING
    bitmap.dispose if bitmap
    self.bitmap = Bitmap.new(width, height)
    self.x = (Graphics.width - width) / 2
    self.y = (Graphics.height - height) / 2
    draw(title, lines, hint)
    self.visible = true
    MGQ_MpUi.log("message box: #{title}: #{MGQ_MpLog.short(text, 160)}")
  end

  # Draws the whole box, the title cut to its width and the hint drawn whole.
  #
  # @param title [String] The title.
  # @param lines [Array<String>] The text's lines.
  # @param hint [String] The hint.
  def draw(title, lines, hint)
    style = MGQ_MpUi::Style
    text_width = bitmap.width - 2 * PADDING
    bitmap.fill_rect(bitmap.rect, style::BACK)
    style.use_font(bitmap, style::TITLE_SIZE, style::TEXT)
    inset = Sprite_MpListBox::TITLE_INSET
    bitmap.draw_text(PADDING, inset, text_width, Sprite_MpListBox::TITLE - 2 * inset, MGQ_MpUi.cut(bitmap, title, text_width))
    bitmap.font.size = style::TEXT_SIZE
    lines.each_with_index { |line, index| bitmap.draw_text(PADDING, Sprite_MpListBox::TITLE + index * ROW, text_width, ROW, line) }
    style.draw_hint(bitmap, PADDING, bitmap.height - Sprite_MpListBox::HINT_HEIGHT - 4, text_width, Sprite_MpListBox::HINT_HEIGHT, hint)
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose if bitmap
    super
  end
end

# The confirm box in the middle of the screen, see MGQ_MpUi::Confirm: the question's lines, the
# two choices side by side with the picked one on its plate, and the hint with their keys. Drawn
# in the shared style, above every box of the mod and across scenes.
class Sprite_MpConfirmBox < Sprite
  # Width of the box.
  WIDTH = 400

  # Height of a text line and of the choice row.
  ROW = 24

  # Width of each choice's box, the two side by side with the style's padding between and around
  # them.
  CHOICE_WIDTH = WIDTH / 2 - 2 * MGQ_MpUi::Style::PAD

  # Creates the box, empty, above every box of the mod.
  def initialize
    super(nil)
    self.z = MGQ_MpUi::Z[:confirm]
    @lines = []
  end

  # Shows a question in the middle of the screen, as high as its lines need.
  #
  # @param question [String] The question.
  # @param yes [String] The yes choice's label.
  # @param no [String] The no choice's label.
  # @param picked [Boolean] Whether yes is picked.
  def show(question, yes, no, picked)
    style = MGQ_MpUi::Style
    measure = Bitmap.new(1, 1)
    style.use_font(measure, style::TEXT_SIZE, style::TEXT)
    @lines = MGQ_MpUi.wrap(measure, question, WIDTH - 2 * style::PAD)
    measure.dispose
    @yes = yes
    @no = no

    height = style::PAD + @lines.size * ROW + style::PAD + ROW + ROW + style::PAD
    bitmap.dispose if bitmap
    self.bitmap = Bitmap.new(WIDTH, height)
    self.x = (Graphics.width - WIDTH) / 2
    self.y = (Graphics.height - height) / 2
    draw(picked)
  end

  # Draws the box anew with the other choice picked.
  #
  # @param picked [Boolean] Whether yes is picked.
  def repick(picked)
    draw(picked) if bitmap
  end

  # Draws the whole box, the hint drawn whole, smaller once the labels make it wider than the box.
  #
  # @param picked [Boolean] Whether yes is picked.
  def draw(picked)
    style = MGQ_MpUi::Style
    pad = style::PAD
    text_width = WIDTH - 2 * pad
    bitmap.clear
    bitmap.fill_rect(bitmap.rect, style::BACK)
    style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
    @lines.each_with_index { |line, index| style.draw_outlined(bitmap, pad, pad + index * ROW, text_width, ROW, line, 1) }

    choices_y = pad + @lines.size * ROW + pad
    draw_choice(@yes, pad, choices_y, picked)
    draw_choice(@no, WIDTH / 2 + pad, choices_y, !picked)

    hint = MGQ_MpUi::Confirm::HINT % [@yes, MGQ_MpHotkeys.label(:accept), @no, MGQ_MpHotkeys.label(:decline)]
    style.draw_hint(bitmap, pad, choices_y + ROW, text_width, ROW, hint)
  end

  # Draws one choice: its label centered in its box, on the picked plate while picked.
  #
  # @param label [String] The label.
  # @param x [Integer] The box's left.
  # @param y [Integer] The box's top.
  # @param picked [Boolean] Whether it is picked.
  def draw_choice(label, x, y, picked)
    style = MGQ_MpUi::Style
    bitmap.fill_rect(x, y, CHOICE_WIDTH, ROW, style::PICKED) if picked
    style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
    style.draw_outlined(bitmap, x, y, CHOICE_WIDTH, ROW, label, 1)
  end

  # Frees the box's picture.
  def dispose
    bitmap.dispose if bitmap
    super
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After every scene's update, the confirm box: every scene's update calls Scene_Base's.
  MGQ_MpHooks.after(Scene_Base, :update, "ui") { MGQ_MpUi::Confirm.tick }

  # After every scene's start, a confirm box still open answers no, before a start that waits in
  # a loop of its own, such as a co-op battle's, would leave it hanging over the scene.
  MGQ_MpHooks.after(Scene_Base, :start, "ui") { MGQ_MpUi::Confirm.leave_scene }
rescue => e
  MGQ_MpUi.log("hooks FAILED: #{e.class}: #{e.message}")
end
