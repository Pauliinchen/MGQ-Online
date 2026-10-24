#----------------------------------------------------------------
#  ui.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Counted the confirm box's frames as the title screen does too
#      Paulinchen  2026-10-13: Added the single player settings' Mod Config group, MGQ Online SP
#      Paulinchen  2026-10-12: Gave the tabs not picked the edge's color, darkened
#                            - Added the scrollbar every scrolling box draws and its track color
#                            - Scrolled the list box with the mouse wheel and drew its scrollbar
#                            - Added the mouse wheel and the scrollbar of the mod's list windows
#                            - Cut a text to its width with far fewer measures
#                            - Listed the settings in their own Mod Config group, MGQ Online Settings
#      Paulinchen  2026-10-11: Let the player move and resize the list, message and confirm boxes with Alt
#                            - Drew the list, message and confirm boxes in their frame
#                            - Dressed the lines across the top of a screen in the interface look
#                            - Made the style's box colors the interface preset's and added more colors
#                            - Added the framed box, its frame alone and the interface option rows
#                            - Added the depth of the layout's outlines
#                            - Turned the font's own outline off while drawing a solid outline
#                            - Kept a copy of the font's color while drawing an outline
#                            - Named every player outside the party in plain white
#                            - Drew the list box and the message box in the shared style
#                            - Placed the list box and the message box by the screen's size
#                            - Drew a hint whole, smaller once it is wider than its room
#                            - Added the fading of a text's color and dropped WHITE
#                            - Added the shared style of the mod's flat boxes
#                            - Added the motion of a sprite
#                            - Added the color of a player
#                            - Added the confirm box
#                            - Named the frames per second and how seconds are written
#                            - Added the icon drawn at any side and the room an icon takes in a row
#                            - Added the depth of the edge arrows and the bounds helper
#                            - Added the rows a box shows of a longer list
#      Paulinchen  2026-10-10: Added the room a strip takes at the top of the map and grouped numbers
#      Paulinchen  2026-10-08: Added the depth of the chat while the player types
#                            - Added the cancel of the mod's screens
#                            - Took the numpad's 0 frame by frame
#                            - Watched the numpad's 0 from the start
#      Paulinchen  2026-10-07: Added the iconset rect, the cut, white and the depths of the mod's sprites
#                            - Logged every message box shown
#      Paulinchen  2026-10-06: Dropped the wrapped lines the top window kept but never read
#                            - Let a list box say a hint of its own and named how high it lies
#                            - Drew an item being typed into as a text box
#                            - Drew buttons at the right end of an item
#      Paulinchen  2026-10-04: Added the message box
#                            - Renamed from mp_ui.rbx
#                            - Drew a list box's item in gold when asked
#                            - Broke the top lines anew only when they changed and darkened the list box
#                            - Added the list box
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

  # The depths of the mod's sprites and windows above the game's, by layer, lowest first; :wheels
  # also holds what lies above a screen's windows.
  Z = { :arrows => 190, :lines => 200, :labels => 250, :bubbles => 260, :wheels => 300, :overview => 400, :boxes => 1000, :confirm => 1050, :typing => 1100, :layout => 1200 }

  # The first words of every setting's row in the Mod Config, which list the settings in a group of
  # their own, apart from the hotkeys (see MGQ_MpHotkeys::GROUP).
  OPTION_PREFIX = "[MGQ Online Settings] "

  # The first words of every row in the Mod Config that applies only outside a world, which list
  # the single player settings in a group of their own.
  SP_PREFIX = "[MGQ Online SP] "

  # What every flat box of the mod draws with: one background in one frame, one plate behind a line
  # on a busy picture, one picked row, one set of text colors, one set of font sizes, one padding,
  # one solid outline and the timings of the fades and slides.
  #
  # The colors from BACK to TAB are the interface preset's: ui_theme.rbx sets them in place, so a
  # constant elsewhere that names one of them follows the preset too, and a copy of one would not.
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

    # Headings, places' headings and key hints.
    HEADING = Color.new(160, 200, 255)

    # Thin frame of every flat box, of the chat's tabs and of a gauge.
    EDGE = Color.new(140, 140, 140, 220)

    # A scrollbar's track, a lane a shade lighter than the box under its thumb; at least as opaque as
    # the box, since fill_rect replaces the pixels and a see-through track would cut a hole down to
    # the map.
    TRACK = Color.new(48, 48, 48, 200)

    # Line around the edge, see draw_frame; fully see-through for a preset whose frame is the edge
    # alone.
    RIM = Color.new(0, 0, 0, 0)

    # A box's title and a raid boss's name above its bar.
    TITLE = Color.new(255, 255, 255)

    # Empty part of a gauge.
    WELL = Color.new(0, 0, 0, 220)

    # Background of a tab that is not picked, the edge's color darkened.
    TAB = Color.new(64, 64, 64, 170)

    # Solid black outline of every text and gauge frame; the game's own outline is half see-through.
    OUTLINE = Color.new(0, 0, 0, 255)

    # Pixels the outline's copies reach around a text, see draw_outlined.
    OUTLINE_REACH = 1

    # Plain text, also the name of a player outside the party.
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
    # The font's own outline is off meanwhile: on each copy it would reach a pixel further, twice
    # as thick as OUTLINE_REACH.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] The box's left.
    # @param y [Integer] The box's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The box's height.
    # @param text [String] The text.
    # @param align [Integer] 0 for left, 1 for centered, 2 for right, as Bitmap#draw_text takes it.
    def self.draw_outlined(bitmap, x, y, width, height, text, align = 0)
      # Font#color returns the font's own color, which Font#color= overwrites, so only a copy keeps it.
      font_color = bitmap.font.color
      color = Color.new(font_color.red, font_color.green, font_color.blue, font_color.alpha)
      outline = bitmap.font.outline
      bitmap.font.outline = false
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
      bitmap.font.outline = outline
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

    # Draws a flat box: BACK inside its frame, see draw_frame.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] The box's left.
    # @param y [Integer] The box's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The box's height.
    def self.draw_box(bitmap, x, y, width, height)
      bitmap.fill_rect(x, y, width, height, BACK)
      draw_frame(bitmap, x, y, width, height)
    end

    # Draws a box's frame along its inside: the RIM outermost and the EDGE within it, or the EDGE
    # alone while the RIM is see-through.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] The box's left.
    # @param y [Integer] The box's top.
    # @param width [Integer] The box's width.
    # @param height [Integer] The box's height.
    # @param edge [Color] The edge's color, another than EDGE for a box that stands out, such as one
    #   being moved.
    def self.draw_frame(bitmap, x, y, width, height, edge = EDGE)
      inset = 0
      if RIM.alpha.to_i > 0
        draw_line_box(bitmap, x, y, width, height, RIM)
        inset = 1
      end
      draw_line_box(bitmap, x + inset, y + inset, width - 2 * inset, height - 2 * inset, edge)
    end

    # Tells how many pixels a box's frame takes on each side, which its content stays inside.
    #
    # @return [Integer] 2 with a RIM, else 1.
    def self.frame_width
      RIM.alpha.to_i > 0 ? 2 : 1
    end

    # Draws a rectangle's outline, one pixel thick, inside the rectangle.
    #
    # @param bitmap [Bitmap] The bitmap.
    # @param x [Integer] Its left.
    # @param y [Integer] Its top.
    # @param width [Integer] Its width.
    # @param height [Integer] Its height.
    # @param color [Color] The line's color.
    def self.draw_line_box(bitmap, x, y, width, height, color)
      return if width <= 0 || height <= 0

      bitmap.fill_rect(x, y, width, 1, color)
      bitmap.fill_rect(x, y + height - 1, width, 1, color)
      bitmap.fill_rect(x, y + 1, 1, height - 2, color)
      bitmap.fill_rect(x + width - 1, y + 1, 1, height - 2, color)
    end

    # Width of a scrollbar.
    SCROLLBAR_WIDTH = 4

    # Least length of a scrollbar's thumb.
    SCROLLBAR_THUMB = 8

    # Draws a scrollbar: its track, and a thumb in the edge color as long as the share of the lines in
    # sight and placed by the first of them; nothing while every line fits.
    #
    # @param bitmap [Bitmap] The picture.
    # @param x [Integer] The bar's left.
    # @param y [Integer] The bar's top.
    # @param height [Integer] The bar's height.
    # @param first [Integer] The first line in sight.
    # @param shown [Integer] How many lines show at once.
    # @param total [Integer] How many lines there are.
    def self.draw_scrollbar(bitmap, x, y, height, first, shown, total)
      return if total <= shown || height <= 0

      thumb = [[height * shown / total, SCROLLBAR_THUMB].max, height].min
      top = y + (height - thumb) * [[first, 0].max, total - shown].min / (total - shown)
      bitmap.fill_rect(x, y, SCROLLBAR_WIDTH, height, TRACK)
      bitmap.fill_rect(x, top, SCROLLBAR_WIDTH, thumb, EDGE)
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

  # The pixels a strip of the mod takes at the top of the map's screen, see top_room.
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

  # Adds a row with values to the Mod Config whose value the mod keeps itself, in Player.ini, so it
  # holds in every save and stays the player's own in a world that sets everyone's options.
  #
  # Only a Mod Config Remake that knows :mod_stored rows reads such a row's value from the mod; an
  # older menu would store it in the save, so it gets none.
  #
  # @param key [Symbol] The row's key.
  # @param name [String] Its name after the group's prefix.
  # @param help [String] Its help.
  # @param values [Proc] Lists its values, as texts the menu shows.
  # @param read [Proc] Reads its value.
  # @param write [Proc] Takes the value picked.
  # @param prefix [String] The group's prefix, OPTION_PREFIX or SP_PREFIX.
  # @return [Boolean] Whether the row was added.
  def self.add_option(key, name, help, values, read, write, prefix = OPTION_PREFIX)
    return false unless defined?(ModConfigRemake) && ModConfigRemake.respond_to?(:mod_stored?)

    NWConst::Config::MOD_CONTENTS.insert(-2, :key => key, :name => prefix + name, :sub => true, :help => help, :values => values,
                                             :mod_stored => true, :value => read, :on_change => write, :personal => true)
    true
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

    # Halving the length keeps the measures few, which are slow in the game.
    fits = 0
    over = text.size
    while over - fits > 1
      length = (fits + over) / 2
      measure.text_size("#{text[0, length].rstrip}#{ELLIPSIS}#{tail}").width <= width ? fits = length : over = length
    end
    "#{text[0, fits].rstrip}#{ELLIPSIS}#{tail}"
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
  # motion, calls update once a frame where it updates the sprite, and never sets visible or
  # opacity itself.
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
  # for a party member and Style::TEXT for anyone else.
  module PlayerColor
    # What the player's own color is called in the log.
    OWN_NAME = "own"

    # What a party member's color is called in the log.
    MEMBER_NAME = "member"

    # What anyone else's color is called in the log.
    PLAIN_NAME = "plain"

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
    # member, else Style::TEXT, also for one it cannot read.
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @param member [Boolean, nil] Whether they are in the player's party; nil derives it from a
    #   peer's member, a state hash through MGQ_MpCoop::Party.member? once coop loaded, false for
    #   an id.
    # @param own [Boolean, nil] Whether they are the player; nil derives it from :me, or an id equal
    #   to MGQ_MpOverworldSync::Me.id once overworld_sync loaded.
    # @return [Color] The color.
    def self.of(who, member = nil, own = nil)
      { :own => Style::OWN, :member => Style::MEMBER }.fetch(pick(who, member, own), Style::TEXT)
    end

    # Names a player's color for the log: "own", "member" or "plain".
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @param member [Boolean, nil] See of.
    # @param own [Boolean, nil] See of.
    # @return [String] The name.
    def self.label(who, member = nil, own = nil)
      { :own => OWN_NAME, :member => MEMBER_NAME }.fetch(pick(who, member, own), PLAIN_NAME)
    end

    # Tells which of the three a player is, which of and label name in their own way.
    #
    # @param who [Peer, Hash, String, Symbol] See id_of.
    # @param member [Boolean, nil] See of.
    # @param own [Boolean, nil] See of.
    # @return [Symbol] :own for the player themself, :member for a party member, :plain for anyone
    #   else or one it cannot read.
    def self.pick(who, member = nil, own = nil)
      return :own if own.nil? ? own?(who) : own
      return :member if member.nil? ? member?(who) : member

      :plain
    rescue
      :plain
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

    # Whether a box is open, see open?.
    @open = false

    # The answer kept for the next tick and what gave it, nil until one is given.
    @answer = nil

    # The box's sprite, nil while none shows.
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
      @asked_at = MGQ_Multiplayer::Key.frame
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
      return if $mgq_text_input || MGQ_Multiplayer::Key.frame == @asked_at

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

module MGQ_MpUi
  module Theme
    # Marks a window of the mod, see ui_theme.rbx.
    #
    # Declared here, since Window_MpInfo includes it as it is defined, before ui_theme.rbx loads.
    module Skinned
    end
  end

  # Lets a list window of the mod scroll with the mouse wheel while the mouse points at it, and
  # shows a scrollbar in its right padding while its rows outgrow it. Included into a
  # Window_Selectable.
  module ScrollingWindow
    # Rows one notch of the wheel scrolls.
    WHEEL_ROWS = 1

    # Updates the window as its class does, then scrolls it with the wheel and keeps the
    # scrollbar where its rows stand.
    def update
      super
      scroll_by_wheel
      update_scrollbar
    end

    # Hides the scrollbar with the window, also when the window is not updated any more.
    #
    # @param visible [Boolean] Whether the window shows.
    def visible=(visible)
      super
      @mgq_mp_scrollbar.visible = false if @mgq_mp_scrollbar && !visible
    end

    # Scrolls the rows by the wheel's notches while the mouse points at the window, moving the
    # cursor along into sight.
    #
    # @return [Boolean] Whether it scrolled.
    def scroll_by_wheel
      notches = MGQ_Multiplayer::Mouse.wheel
      return false if notches == 0 || !wheel_ready? || !pointed_at?

      before = top_row
      self.top_row = top_row - notches * WHEEL_ROWS
      return false if top_row == before

      keep_cursor_in_sight
      true
    end

    # Tells whether the window takes the wheel: shown, open, with more rows than fit, and free to
    # scroll.
    #
    # @return [Boolean] Whether it does.
    def wheel_ready?
      visible && open? && row_max > page_row_max && takes_wheel?
    end

    # Tells whether the window is free to scroll: while it takes the input, or has no cursor to
    # keep in sight. A window may narrow it.
    #
    # @return [Boolean] Whether it is.
    def takes_wheel?
      active || index < 0
    end

    # Tells whether the mouse points at the window.
    #
    # @return [Boolean] Whether it does.
    def pointed_at?
      position = MGQ_Multiplayer::Mouse.position
      return false unless position

      left = x + (viewport ? viewport.rect.x - viewport.ox : 0)
      top = y + (viewport ? viewport.rect.y - viewport.oy : 0)
      position[0] >= left && position[0] < left + width && position[1] >= top && position[1] < top + height
    end

    # Moves the cursor onto the nearest row in sight once the rows scrolled it out of sight, and
    # draws it where its row lies now.
    def keep_cursor_in_sight
      return update_cursor if index < 0

      first = top_row * col_max
      last = [(top_row + page_row_max) * col_max, item_max].min - 1
      kept = [[index, first].max, last].min
      kept == index ? update_cursor : select(kept)
    end

    # Draws the scrollbar if the rows moved or changed, the window's size or the interface look
    # changed, and shows it beside the rows while the window shows, open, with more rows than fit.
    def update_scrollbar
      bar = scrollbar
      shown = visible && open? && row_max > page_row_max
      bar.visible = shown
      return unless shown

      height = self.height - padding - padding_bottom
      bar.viewport = viewport unless bar.viewport == viewport
      bar.x = x + width - (padding + Style::SCROLLBAR_WIDTH) / 2
      bar.y = y + padding
      bar.z = z + 1
      drawn = [height, row_max, page_row_max, top_row, Theme.serial]
      return if drawn == @mgq_mp_scrollbar_drawn

      @mgq_mp_scrollbar_drawn = drawn
      unless bar.bitmap && bar.bitmap.height == height
        bar.bitmap.dispose if bar.bitmap
        bar.bitmap = Bitmap.new(Style::SCROLLBAR_WIDTH, [height, 1].max)
      end
      bar.bitmap.clear
      Style.draw_scrollbar(bar.bitmap, 0, 0, height, top_row, page_row_max, row_max)
    end

    # Returns the scrollbar's sprite, made at first ask.
    #
    # @return [Sprite] The sprite.
    def scrollbar
      @mgq_mp_scrollbar ||= Sprite.new(viewport)
    end

    # Frees the scrollbar with the window.
    def dispose
      if @mgq_mp_scrollbar
        @mgq_mp_scrollbar.bitmap.dispose if @mgq_mp_scrollbar.bitmap
        @mgq_mp_scrollbar.dispose
        @mgq_mp_scrollbar = nil
      end
      super
    end
  end
end

# The lines across the top of a screen of the mod, such as the world screen's.
class Window_MpInfo < Window_Base
  include MGQ_MpUi::Theme::Skinned

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
# closes it; the box only draws. The player moves and resizes it with Alt (MGQ_MpUi::Layout): the
# items take the width the fixed columns at their right leave, and the list as many lines as fit.
class Sprite_MpListBox < Sprite
  # Room between the box and either side of the screen where it starts.
  SIDE = 40

  # Room between the box and the top of the screen where it starts.
  TOP = 32

  # Room between the box and the bottom of the screen where it starts.
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

  # Pixels the scrollbar keeps from the box's right edge.
  SCROLLBAR_INSET = 4

  # Lines one notch of the mouse wheel scrolls unless the list's owner says another.
  WHEEL_LINES = 1

  # What the hint says unless the list says another.
  HINT = ["Up and down: move", MGQ_MpUi::Style.close_hint("a click outside")].join(MGQ_MpUi::Style::HINT_GAP)

  # The box's place in the layout.
  LAYOUT_ID = :list_box

  # The box's name in the outlines.
  LAYOUT_NAME = "List box"

  # Least width of an item's text and of the title's start, so a name stays readable.
  ITEM_MIN = 144

  # Most columns of buttons an item has, the mod picker's two.
  MOST_BUTTONS = 2

  # Fewest lines of the list the box shows.
  MIN_ROWS = 3

  # Least width of the box: an item's text at ITEM_MIN with what its right end says and the most
  # buttons beside it.
  MIN_WIDTH = ITEM_LEFT + ITEM_MIN + ITEM_GAP + RIGHT_WIDTH + EDGE + MOST_BUTTONS * BUTTON_COLUMN + BUTTON_MARGIN

  # Least height of the box: the title, MIN_ROWS lines and the hint.
  MIN_HEIGHT = TITLE + MIN_ROWS * ROW + LIST_ROOM + HINT_HEIGHT

  # Tells where the box starts on the screen: SIDE from either side, TOP from the top and BOTTOM
  # from the bottom, read from the screen once it is first asked.
  #
  # @return [Rect] The box.
  def self.box
    @box ||= Rect.new(SIDE, TOP, Graphics.width - 2 * SIDE, Graphics.height - TOP - BOTTOM)
  end

  # Tells where the box lies now: where the player left it, else where it starts.
  #
  # @return [Rect] The box.
  def self.rect
    register_layout
    MGQ_MpUi::Layout.rect(LAYOUT_ID, box)
  end

  # Makes the box movable with its least size, or another least width once a list needs more;
  # nothing while the least width stays.
  #
  # @param min_width [Integer, nil] The least width, nil for the one registered, MIN_WIDTH at first.
  def self.register_layout(min_width = nil)
    least = min_width || @least || MIN_WIDTH
    return if least == @least

    @least = least
    MGQ_MpUi::Layout.register(LAYOUT_ID, LAYOUT_NAME, least, MIN_HEIGHT)
  end

  # Tells the least width a list needs: MIN_WIDTH, its note whole after ITEM_MIN of the title, and
  # its hint whole at the smaller size, as far as the box's width where it starts gives it, since a
  # longer hint is squeezed there already.
  #
  # @param view [View] What the box lists.
  # @return [Integer] The width.
  def self.least_width(view)
    style = MGQ_MpUi::Style
    title = 2 * EDGE + ITEM_MIN + (view.note ? measure(view.note, style::TITLE_SIZE) + style::PAD : 0)
    hint = [measure(view.hint || HINT, style::TINY_SIZE) + 2 * EDGE, box.width].min
    [MIN_WIDTH, title, hint].max
  end

  # Measures a text in the style's font at a size, which the boxes of this script share.
  #
  # @param text [String] The text.
  # @param size [Integer] The font's size.
  # @return [Integer] Its width in pixels.
  def self.measure(text, size)
    @measure = Bitmap.new(1, 1) if @measure.nil? || @measure.disposed?
    MGQ_MpUi::Style.use_font(@measure, size, MGQ_MpUi::Style::TEXT)
    @measure.text_size(text.to_s).width
  end

  # Tells how many lines of the list the box shows at once.
  #
  # @param height [Integer] The box's height, the height it has now by default.
  # @return [Integer] The lines.
  def self.list_rows(height = rect.height)
    (height - TITLE - HINT_HEIGHT - LIST_ROOM) / ROW
  end

  # What the box lists.
  #
  # @!attribute title [String] The title at the top left.
  # @!attribute note [String, nil] What the top right says.
  # @!attribute lines [Array<Array>] [:head, text, titles] for a heading, titles nil or those of the
  #   button columns below it; [:item, text, color, right, buttons] for an item: color is :plain,
  #   :good, :gold, :bad or :grey, right what its right end says or nil, buttons nil or each
  #   button's mark, color (:red or :orange) and whether it is on. An item being typed into adds
  #   [editor, text, cursor, cursor shown], its text the box's label.
  # @!attribute selected [Integer, nil] The line of the item picked, nil without items.
  # @!attribute scroll [Integer] The first line in sight.
  # @!attribute hint [String, nil] What the bottom says, nil for HINT.
  # @!attribute column [Integer, nil] The button of the picked item the cursor is on, from 1; nil or
  #   0 for the item itself.
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

    # Tells whether the item picked lies outside the lines in sight.
    #
    # @param rows [Integer] The lines the box shows.
    # @return [Boolean] Whether it does; false without an item picked.
    def out_of_sight?(rows)
      !selected.nil? && (selected < scroll || selected >= scroll + rows)
    end

    # Scrolls the lines, within the list, and moves the pick along onto the nearest item in sight
    # once it left the lines in sight.
    #
    # @param step [Integer] Lines to scroll down, a negative number to scroll up.
    # @param rows [Integer] The lines the box shows.
    # @return [Boolean] Whether it scrolled.
    def scroll_by(step, rows)
      top = [[scroll + step, lines.size - rows].min, 0].max
      return false if top == scroll

      self.scroll = top
      in_sight = items.select { |line| line >= top && line < top + rows }
      self.selected = selected < top ? in_sight.first : in_sight.last if out_of_sight?(rows) && !in_sight.empty?
      true
    end
  end

  # Scrolls a list the box shows by the mouse wheel's notches while the mouse points at the box.
  #
  # @param view [View] What the box lists.
  # @param step [Integer] Lines one notch scrolls.
  # @return [Boolean] Whether it scrolled.
  def self.scroll_by_wheel(view, step = WHEEL_LINES)
    notches = MGQ_Multiplayer::Mouse.wheel
    return false if notches == 0

    position = MGQ_Multiplayer::Mouse.position
    position && inside?(position[0], position[1]) ? view.scroll_by(-notches * step, list_rows) : false
  end

  # Creates the box, hidden, above every window, where it lies now.
  def initialize
    super(nil)
    rect = self.class.rect
    self.bitmap = Bitmap.new(rect.width, rect.height)
    self.x = rect.x
    self.y = rect.y
    self.z = Z
    @motion = MGQ_MpUi::Motion.new(self)
    @shown = nil
    @view = nil
  end

  # Reports whether a point of the screen lies in the box.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param place [Rect] The box, where it lies now by default.
  # @return [Boolean] Whether it does.
  def self.inside?(x, y, place = rect)
    x >= place.x && x < place.x + place.width && y >= place.y && y < place.y + place.height
  end

  # Finds the button of an item under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param count [Integer] How many buttons the item has.
  # @return [Integer, nil] The button, from 1 at the left; nil outside them.
  def self.button_at(x, count)
    place = rect
    (1..count).find do |button|
      left = place.x + column_left(button, count, place.width)
      x >= left && x < left + BUTTON_COLUMN
    end
  end

  # Tells where a column of buttons starts, inside the box.
  #
  # @param button [Integer] The column, from 1 at the left.
  # @param count [Integer] How many columns there are.
  # @param width [Integer] The box's width, the width it has now by default.
  # @return [Integer] Its left edge.
  def self.column_left(button, count, width = rect.width)
    width - BUTTON_MARGIN - (count - button + 1) * BUTTON_COLUMN
  end

  # Tells where a button of an item starts, inside the box: in the middle of its column.
  #
  # @param button [Integer] The button, from 1 at the left.
  # @param count [Integer] How many buttons the item has.
  # @param width [Integer] The box's width, the width it has now by default.
  # @return [Integer] Its left edge.
  def self.button_left(button, count, width = rect.width)
    column_left(button, count, width) + (BUTTON_COLUMN - BUTTON_SIZE) / 2
  end

  # Finds the line of the list under a point of the screen.
  #
  # @param x [Integer] The point's x.
  # @param y [Integer] The point's y.
  # @param view [View] What the box lists.
  # @return [Integer, nil] The line, nil outside the list.
  def self.line_at(x, y, view)
    place = rect
    return nil unless inside?(x, y, place) && y >= place.y + TITLE

    row = (y - place.y - TITLE) / ROW
    line = view.scroll + row
    row < list_rows(place.height) && line < view.lines.size ? line : nil
  end

  # Shows a list, fading it in, drawing it if it, the box's size or the interface look changed;
  # the item picked is scrolled into sight once a smaller box hides it.
  #
  # @param view [View] What the box lists.
  def show(view)
    @motion.show
    needs = [view.note, view.hint]
    if needs != @needs
      @needs = needs
      self.class.register_layout(self.class.least_width(view))
    end
    @view = view
    follow_layout
    view.pick(view.selected) if view.out_of_sight?(self.class.list_rows(bitmap.height))
    drawn = view.to_a + [bitmap.width, bitmap.height, MGQ_MpUi::Theme.serial]
    return if drawn == @shown

    @shown = drawn.map { |part| part.is_a?(Array) ? part.dup : part }
    draw(view)
  end

  # Fades the box out, keeping its picture until it is gone.
  def hide
    @motion.hide
    @shown = nil
  end

  # Follows the layout and moves the fade a frame on, and offers the box to the layout while it
  # shows. Called every frame by the screen that owns the box.
  def update
    super
    follow_layout
    @motion.update
    MGQ_MpUi::Layout.offer(LAYOUT_ID, x, y, bitmap.width, bitmap.height, z) if @motion.shown?
  end

  # Takes the place the layout gives: a picture of the new size, with the list drawn anew, once the
  # size changed, and the place without a slide.
  def follow_layout
    rect = self.class.rect
    if rect.width != bitmap.width || rect.height != bitmap.height
      bitmap.dispose
      self.bitmap = Bitmap.new(rect.width, rect.height)
      @shown = nil
      draw(@view) if @view
    end
    @motion.place(rect.x, rect.y)
  end

  # Draws the whole box: its back in its frame, the title with its note at the right, the lines in
  # sight with a scrollbar at their right while not all fit, the hint.
  #
  # @param view [View] What the box lists.
  def draw(view)
    style = MGQ_MpUi::Style
    width = bitmap.width
    bitmap.clear
    style.draw_box(bitmap, 0, 0, width, bitmap.height)
    style.use_font(bitmap, style::TITLE_SIZE, style::GOOD)
    note_width = view.note ? bitmap.text_size(view.note).width + style::PAD : 0
    bitmap.draw_text(EDGE, TITLE_INSET, width - 2 * EDGE, TITLE - 2 * TITLE_INSET, view.note, 2) if view.note
    style.use_font(bitmap, style::TITLE_SIZE, style::TEXT)
    bitmap.draw_text(EDGE, TITLE_INSET, width - 2 * EDGE, TITLE - 2 * TITLE_INSET, MGQ_MpUi.cut(bitmap, view.title, width - 2 * EDGE - note_width))
    rows = self.class.list_rows(bitmap.height)
    lines = view.lines[view.scroll, rows] || []
    lines.each_with_index { |line, index| draw_line(line, TITLE + index * ROW, view.scroll + index == view.selected, view.column.to_i) }
    style.draw_scrollbar(bitmap, width - SCROLLBAR_INSET - style::SCROLLBAR_WIDTH, TITLE, rows * ROW, view.scroll, rows, view.lines.size)
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
      x = self.class.button_left(index + 1, buttons.size, width)
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
      left = self.class.column_left(index + 1, titles.size, bitmap.width)
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
# The player moves it and changes its width with Alt (MGQ_MpUi::Layout); its height follows the
# lines the text breaks into.
class Sprite_MpMessageBox < Sprite
  # Room between the box and either side of the screen where it starts.
  SIDE = 80

  # Room between the box's edges and its text.
  PADDING = 2 * MGQ_MpUi::Style::PAD

  # Height of one line of the text.
  ROW = 24

  # The box's place in the layout.
  LAYOUT_ID = :message_box

  # The box's name in the outlines.
  LAYOUT_NAME = "Message box"

  # Least width of the box: the text's room as wide as the list box's least item.
  MIN_WIDTH = Sprite_MpListBox::ITEM_MIN + 2 * PADDING

  # Least height of the box: the title, a line and the hint.
  MIN_HEIGHT = Sprite_MpListBox::TITLE + ROW + Sprite_MpListBox::HINT_HEIGHT + PADDING

  # The boxes made and not freed, see boxes.
  @boxes = []

  # Lists the boxes made and not freed, which follow the layout once a frame.
  #
  # @return [Array<Sprite_MpMessageBox>] The boxes.
  def self.boxes
    @boxes
  end

  # Has every box that shows follow the layout. Called after every Graphics.update, since whoever
  # shows a box only closes it.
  def self.follow_layouts
    @boxes.each { |box| box.follow_layout if box.visible && !box.disposed? }
  end

  # Makes the box movable with its least size, or another least width once a hint needs more;
  # nothing while the least width stays.
  #
  # @param min_width [Integer, nil] The least width, nil for the one registered, MIN_WIDTH at first.
  def self.register_layout(min_width = nil)
    least = min_width || @least || MIN_WIDTH
    return if least == @least

    @least = least
    MGQ_MpUi::Layout.register(LAYOUT_ID, LAYOUT_NAME, least, MIN_HEIGHT, :width)
  end

  # Tells the least width a hint needs: MIN_WIDTH, and the hint whole at the smaller size, as far as
  # the box's width where it starts gives it.
  #
  # @param hint [String] The hint.
  # @return [Integer] The width.
  def self.least_width(hint)
    hint_width = Sprite_MpListBox.measure(hint, MGQ_MpUi::Style::TINY_SIZE) + 2 * PADDING
    [MIN_WIDTH, [hint_width, Graphics.width - 2 * SIDE].min].max
  end

  # Creates the box, hidden, above every window.
  def initialize
    super(nil)
    self.z = MGQ_MpUi::Z[:boxes]
    self.visible = false
    self.class.boxes.push(self)
  end

  # Shows a message, as wide as the screen leaves between SIDE on either side and as high as its
  # lines need, in the middle of the screen unless the player moved it.
  #
  # @param title [String] The title at the top.
  # @param text [String] The text.
  # @param hint [String] What the hint at the bottom says.
  def show(title, text, hint)
    @title = title.to_s
    @text = text.to_s
    @hint = hint.to_s
    @lines = nil
    @drawn = nil
    self.class.register_layout(self.class.least_width(@hint))
    width = Graphics.width - 2 * SIDE
    height = height_of(lines_at(width))
    @default = Rect.new((Graphics.width - width) / 2, (Graphics.height - height) / 2, width, height)
    follow_layout
    self.visible = true
    MGQ_MpUi.log("message box: #{title}: #{MGQ_MpLog.short(text, 160)}")
  end

  # Takes the place the layout gives: the text broken anew and the box drawn anew once its width or
  # the interface look changed, as high as the lines need and wholly on the screen, and offers the
  # box to the layout.
  def follow_layout
    return unless @default

    rect = MGQ_MpUi::Layout.rect(LAYOUT_ID, @default)
    lines = lines_at(rect.width)
    height = height_of(lines)
    drawn = [rect.width, height, MGQ_MpUi::Theme.serial]
    if drawn != @drawn
      @drawn = drawn
      bitmap.dispose if bitmap
      self.bitmap = Bitmap.new(rect.width, height)
      draw(@title, lines, @hint)
    end
    self.x = rect.x
    self.y = MGQ_MpUi.within(rect.y, 0, [Graphics.height - height, 0].max)
    MGQ_MpUi::Layout.offer(LAYOUT_ID, x, y, rect.width, height, z)
  end

  # Breaks the text into the lines that fit a width, kept for the last width asked.
  #
  # @param width [Integer] The box's width.
  # @return [Array<String>] The lines.
  def lines_at(width)
    return @lines if @lines && @lines_width == width

    style = MGQ_MpUi::Style
    measure = Bitmap.new(1, 1)
    style.use_font(measure, style::TEXT_SIZE, style::TEXT)
    @lines = MGQ_MpUi.wrap(measure, @text, width - 2 * PADDING)
    @lines_width = width
    measure.dispose
    @lines
  end

  # Tells how high the box is with a number of lines.
  #
  # @param lines [Array<String>] The lines.
  # @return [Integer] The height.
  def height_of(lines)
    Sprite_MpListBox::TITLE + lines.size * ROW + Sprite_MpListBox::HINT_HEIGHT + PADDING
  end

  # Draws the whole box, its back in its frame, the title cut to its width and the hint drawn whole.
  #
  # @param title [String] The title.
  # @param lines [Array<String>] The text's lines.
  # @param hint [String] The hint.
  def draw(title, lines, hint)
    style = MGQ_MpUi::Style
    text_width = bitmap.width - 2 * PADDING
    style.draw_box(bitmap, 0, 0, bitmap.width, bitmap.height)
    style.use_font(bitmap, style::TITLE_SIZE, style::TEXT)
    inset = Sprite_MpListBox::TITLE_INSET
    bitmap.draw_text(PADDING, inset, text_width, Sprite_MpListBox::TITLE - 2 * inset, MGQ_MpUi.cut(bitmap, title, text_width))
    bitmap.font.size = style::TEXT_SIZE
    lines.each_with_index { |line, index| bitmap.draw_text(PADDING, Sprite_MpListBox::TITLE + index * ROW, text_width, ROW, line) }
    style.draw_hint(bitmap, PADDING, bitmap.height - Sprite_MpListBox::HINT_HEIGHT - 4, text_width, Sprite_MpListBox::HINT_HEIGHT, hint)
  end

  # Frees the box's picture.
  def dispose
    self.class.boxes.delete(self)
    bitmap.dispose if bitmap
    super
  end
end

# The confirm box in the middle of the screen, see MGQ_MpUi::Confirm: the question's lines, the
# two choices side by side with the picked one on its plate, and the hint with their keys. Drawn
# in the shared style, above every box of the mod and across scenes. The player moves it and
# changes its width with Alt (MGQ_MpUi::Layout); its height follows the question's lines.
class Sprite_MpConfirmBox < Sprite
  # Width of the box where it starts.
  WIDTH = 400

  # Height of a text line and of the choice row.
  ROW = 24

  # The box's place in the layout.
  LAYOUT_ID = :confirm_box

  # The box's name in the outlines.
  LAYOUT_NAME = "Confirm box"

  # Least width of the box: the question's room as wide as the list box's least item.
  MIN_WIDTH = Sprite_MpListBox::ITEM_MIN + 2 * MGQ_MpUi::Style::PAD

  # Least height of the box: a line of the question, the choices and the hint.
  MIN_HEIGHT = 3 * ROW + 3 * MGQ_MpUi::Style::PAD

  # The boxes made and not freed, see boxes.
  @boxes = []

  # Lists the boxes made and not freed, which follow the layout once a frame.
  #
  # @return [Array<Sprite_MpConfirmBox>] The boxes.
  def self.boxes
    @boxes
  end

  # Has every box that shows follow the layout. Called after every Graphics.update.
  def self.follow_layouts
    @boxes.each { |box| box.follow_layout if box.visible && !box.disposed? }
  end

  # Makes the box movable with its least size, or another least width once its choices need more;
  # nothing while the least width stays.
  #
  # @param min_width [Integer, nil] The least width, nil for the one registered, MIN_WIDTH at first.
  def self.register_layout(min_width = nil)
    least = min_width || @least || MIN_WIDTH
    return if least == @least

    @least = least
    MGQ_MpUi::Layout.register(LAYOUT_ID, LAYOUT_NAME, least, MIN_HEIGHT, :width)
  end

  # Tells the least width two choices and their hint need: MIN_WIDTH, each label whole on its
  # choice's plate, and the hint whole at the smaller size, as far as WIDTH gives it.
  #
  # @param yes [String] The yes choice's label.
  # @param no [String] The no choice's label.
  # @param hint [String] The hint.
  # @return [Integer] The width.
  def self.least_width(yes, no, hint)
    style = MGQ_MpUi::Style
    label = [yes, no].map { |text| Sprite_MpListBox.measure(text, style::TEXT_SIZE) }.max
    # A choice's plate is half the box less the padding around it, and its label keeps the padding
    # inside the plate.
    choices = 2 * (label + 4 * style::PAD)
    hint_width = Sprite_MpListBox.measure(hint, style::TINY_SIZE) + 2 * style::PAD
    [MIN_WIDTH, choices, [hint_width, WIDTH].min].max
  end

  # Creates the box, empty, above every box of the mod.
  def initialize
    super(nil)
    self.z = MGQ_MpUi::Z[:confirm]
    self.class.boxes.push(self)
  end

  # Shows a question, as high as its lines need, in the middle of the screen unless the player
  # moved the box.
  #
  # @param question [String] The question.
  # @param yes [String] The yes choice's label.
  # @param no [String] The no choice's label.
  # @param picked [Boolean] Whether yes is picked.
  def show(question, yes, no, picked)
    @question = question.to_s
    @yes = yes
    @no = no
    @picked = picked
    @lines = nil
    @drawn = nil
    self.class.register_layout(self.class.least_width(yes, no, hint))
    height = height_of(lines_at(WIDTH))
    @default = Rect.new((Graphics.width - WIDTH) / 2, (Graphics.height - height) / 2, WIDTH, height)
    follow_layout
  end

  # Draws the box anew with the other choice picked.
  #
  # @param picked [Boolean] Whether yes is picked.
  def repick(picked)
    @picked = picked
    draw(picked) if bitmap
  end

  # Takes the place the layout gives: the question broken anew and the box drawn anew once its
  # width or the interface look changed, as high as the lines need and wholly on the screen, and
  # offers the box to the layout.
  def follow_layout
    return unless @default

    rect = MGQ_MpUi::Layout.rect(LAYOUT_ID, @default)
    height = height_of(lines_at(rect.width))
    drawn = [rect.width, height, MGQ_MpUi::Theme.serial]
    if drawn != @drawn
      @drawn = drawn
      bitmap.dispose if bitmap
      self.bitmap = Bitmap.new(rect.width, height)
      draw(@picked)
    end
    self.x = rect.x
    self.y = MGQ_MpUi.within(rect.y, 0, [Graphics.height - height, 0].max)
    MGQ_MpUi::Layout.offer(LAYOUT_ID, x, y, rect.width, height, z)
  end

  # Breaks the question into the lines that fit a width, kept for the last width asked.
  #
  # @param width [Integer] The box's width.
  # @return [Array<String>] The lines.
  def lines_at(width)
    return @lines if @lines && @lines_width == width

    style = MGQ_MpUi::Style
    measure = Bitmap.new(1, 1)
    style.use_font(measure, style::TEXT_SIZE, style::TEXT)
    @lines = MGQ_MpUi.wrap(measure, @question, width - 2 * style::PAD)
    @lines_width = width
    measure.dispose
    @lines
  end

  # Tells how high the box is with a number of question lines.
  #
  # @param lines [Array<String>] The lines.
  # @return [Integer] The height.
  def height_of(lines)
    pad = MGQ_MpUi::Style::PAD
    pad + lines.size * ROW + pad + ROW + ROW + pad
  end

  # Writes the hint with the choices' labels and their hotkeys.
  #
  # @return [String] The hint.
  def hint
    MGQ_MpUi::Confirm::HINT % [@yes, MGQ_MpHotkeys.label(:accept), @no, MGQ_MpHotkeys.label(:decline)]
  end

  # Tells how wide each choice's plate is in the box as wide as it is now.
  #
  # @return [Integer] The width.
  def choice_width
    bitmap.width / 2 - 2 * MGQ_MpUi::Style::PAD
  end

  # Draws the whole box, its back in its frame, the hint drawn whole, smaller once the labels make
  # it wider than the box.
  #
  # @param picked [Boolean] Whether yes is picked.
  def draw(picked)
    style = MGQ_MpUi::Style
    pad = style::PAD
    width = bitmap.width
    text_width = width - 2 * pad
    lines = lines_at(width)
    bitmap.clear
    style.draw_box(bitmap, 0, 0, width, bitmap.height)
    style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
    lines.each_with_index { |line, index| style.draw_outlined(bitmap, pad, pad + index * ROW, text_width, ROW, line, 1) }

    choices_y = pad + lines.size * ROW + pad
    draw_choice(@yes, pad, choices_y, picked)
    draw_choice(@no, width / 2 + pad, choices_y, !picked)
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
    bitmap.fill_rect(x, y, choice_width, ROW, style::PICKED) if picked
    style.use_font(bitmap, style::TEXT_SIZE, style::TEXT)
    style.draw_outlined(bitmap, x, y, choice_width, ROW, label, 1)
  end

  # Frees the box's picture.
  def dispose
    self.class.boxes.delete(self)
    bitmap.dispose if bitmap
    super
  end
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Scene_Base, :update, "ui") { MGQ_MpUi::Confirm.tick }

  # After every frame, the message boxes and the confirm box follow the layout, which the player
  # changes with Alt, before the layout's tick reads their places: the title screen's update never
  # calls Scene_Base's.
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "ui") do
    Sprite_MpMessageBox.follow_layouts
    Sprite_MpConfirmBox.follow_layouts
  end

  # After every scene's start, a confirm box still open answers no, before a start that waits in
  # a loop of its own, such as a co-op battle's, would leave it hanging over the scene. The boxes
  # of this script become known to the layout then, which loads after this script, so putting
  # every box back in the Mod Config reaches them before they first show.
  MGQ_MpHooks.after(Scene_Base, :start, "ui") do
    MGQ_MpUi::Confirm.leave_scene
    [Sprite_MpListBox, Sprite_MpMessageBox, Sprite_MpConfirmBox].each { |box| box.register_layout }
  end
rescue => e
  MGQ_MpUi.log("hooks FAILED: #{e.class}: #{e.message}")
end
