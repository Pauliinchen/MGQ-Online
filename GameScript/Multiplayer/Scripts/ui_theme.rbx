#----------------------------------------------------------------
#  ui_theme.rbx
#
#  Changelog:
#      Paulinchen  2026-10-24: Added the Game's Default look, which follows the game's window color
#                            - Dressed the game's own windows in the look, unless turned off in the Mod Config
#      Paulinchen  2026-10-12: Gave the tabs not picked the edge's color, darkened
#                            - Added the scrollbar track's color
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

module MGQ_MpUi
  # The interface presets: the colors every box, frame, gauge and window of the mod and of the game
  # is drawn in, the player's pick kept in Player.ini and offered as a row of the Mod Config. A
  # preset sets the style's box colors in place (see MGQ_MpUi::Style), and every window takes a
  # window skin painted in them (see dress); the game's own look takes them from the game's window.
  #
  # It must never interrupt the game, so every entry point rescues.
  module Theme
    extend MGQ_MpLog

    # What starts this script's lines in Multiplayer InGame.log.
    LOG_TAG = "theme"

    # One preset: its name and the color of each of the style's box colors, by the constant's name,
    # as red, green, blue and alpha; no colors for the game's own look, see game_colors.
    Preset = Struct.new(:name, :colors)

    # The name of the look that follows the game's window and its window color.
    GAME_LOOK = "Game's Default"

    # The presets, the first the one until the player picks another: Monarch, the raid boss bar's
    # maroon with a gold edge in a black rim, Legacy, the chat's black glass with a grey edge, and
    # the game's own look.
    PRESETS = [
      Preset.new("Monarch", { :BACK => [36, 10, 14, 235], :PLATE => [36, 10, 14, 200], :PICKED => [120, 36, 52, 235], :FIELD => [20, 6, 8, 255],
                              :HEADING => [240, 204, 130, 255], :EDGE => [200, 164, 96, 230], :TRACK => [84, 50, 38, 240], :RIM => [0, 0, 0, 255],
                              :TITLE => [255, 224, 140, 255], :WELL => [36, 10, 14, 235], :TAB => [100, 78, 40, 235] }),
      Preset.new("Legacy", { :BACK => [0, 0, 0, 170], :PLATE => [0, 0, 0, 150], :PICKED => [48, 96, 176, 220], :FIELD => [12, 16, 28, 255],
                             :HEADING => [160, 200, 255, 255], :EDGE => [140, 140, 140, 220], :TRACK => [48, 48, 48, 200], :RIM => [0, 0, 0, 0],
                             :TITLE => [255, 255, 255, 255], :WELL => [0, 0, 0, 220], :TAB => [64, 64, 64, 170] }),
      Preset.new(GAME_LOOK, nil),
    ]

    # The setting in Player.ini that keeps the preset's name.
    SETTING = "ui_preset"

    # The Mod Config row's key.
    OPTION = :mp_ui_preset

    # The Mod Config row's name.
    OPTION_NAME = "Interface Look"

    # The Mod Config row's help.
    OPTION_HELP = "The look of every box, frame and window: Monarch is the raid boss bar's maroon with a gold\n" \
                  "edge, Legacy black glass, Game's Default the game's window in its Window Color."

    # The setting in Player.ini that keeps whether the game's windows wear the look, 1 or 0.
    GAME_WINDOWS_SETTING = "ui_game_windows"

    # The Mod Config row's key that turns the look on the game's windows on and off.
    GAME_WINDOWS_OPTION = :mp_ui_game_windows

    # The Mod Config row's name that turns the look on the game's windows on and off.
    GAME_WINDOWS_OPTION_NAME = "Look on Game Windows"

    # The Mod Config row's help that turns the look on the game's windows on and off.
    GAME_WINDOWS_OPTION_HELP = "On: the game's own windows wear the Interface Look too.\n" \
                               "Off: they keep the game's Window Color, and only the mod's windows wear it."

    # The Mod Config row's values.
    ON = "On"
    OFF = "Off"

    # The game's window skin in Graphics/System.
    GAME_SKIN = "Window"

    # Side of a window skin, in pixels.
    SKIN_SIDE = 128

    # Where a window skin keeps the background stretched over the window, as x, y, width and height.
    SKIN_BACK = [0, 0, 64, 64]

    # Where a window skin keeps the pattern tiled over the background.
    SKIN_PATTERN = [0, 64, 64, 64]

    # Where a window skin keeps the frame's square.
    SKIN_FRAME = [64, 0, 64, 64]

    # Where a window skin keeps the cursor.
    SKIN_CURSOR = [64, 64, 32, 32]

    # Pixels of the frame's square along its sides that a window draws its borders from; its middle
    # holds the scroll arrows.
    SKIN_BORDER = 16

    # Where a window skin's palette keeps the normal text color and the system text color.
    SKIN_NORMAL_COLOR = [64, 96]
    SKIN_SYSTEM_COLOR = [64, 112]

    # Pixels between the samples a skin's background is averaged from.
    SAMPLE_STEP = 4

    # How opaque the game draws its windows' background, which the game's look gives the boxes.
    GAME_BACK_OPACITY = 192

    # How far the game's look moves the background towards the cursor's color for a picked row,
    # from 0 to 1; a box fills the row instead of laying the see-through cursor over it.
    PICKED_LIFT = 0.3

    # The preset in use.
    @preset = PRESETS.first

    # Counts every change of the colors, which whoever keeps a picture drawn in them compares.
    @serial = 0

    # The window color the game's look was last worked out from, as red, green, blue and gray.
    @tone_seen = nil

    # Lists the presets' names, in the order the Mod Config cycles them.
    #
    # @return [Array<String>] The names.
    def self.names
      PRESETS.map { |preset| preset.name }
    end

    # Tells the preset in use.
    #
    # @return [Preset] The preset.
    def self.current
      @preset
    end

    # Tells whether the game's own look is in use, which leaves the windows to the game.
    #
    # @return [Boolean] Whether it is.
    def self.game?
      @preset.colors.nil?
    end

    # Tells whether the game's windows wear the look, as Player.ini keeps it, on until turned off.
    #
    # @return [Boolean] Whether they do.
    def self.game_windows?
      @game_windows = MGQ_Multiplayer::Player.setting(GAME_WINDOWS_SETTING).to_s != "0" if @game_windows.nil?
      @game_windows
    end

    # Turns the look on the game's windows on or off and keeps it in Player.ini; every window
    # dresses anew on its next update.
    #
    # @param on [Boolean] Whether the game's windows wear the look.
    def self.dress_game_windows(on)
      @game_windows = on
      MGQ_Multiplayer::Player.store(GAME_WINDOWS_SETTING, on ? 1 : 0)
      log("the look on the game's windows is #{on ? 'on' : 'off'}")
    rescue => e
      log("keeping the look on the game's windows FAILED: #{e.class}: #{e.message}")
    end

    # Tells how often the colors changed, so a picture drawn in them knows to draw anew.
    #
    # @return [Integer] The count.
    def self.serial
      @serial
    end

    # Finds a preset by its name, ignoring case.
    #
    # @param name [String, nil] The name.
    # @return [Preset] The preset, the first for an unknown name.
    def self.find(name)
      PRESETS.find { |preset| preset.name.downcase == name.to_s.strip.downcase } || PRESETS.first
    end

    # Puts a preset to use: sets the style's box colors to it in place and counts the change.
    #
    # @param name [String, nil] The preset's name, the first preset's for an unknown one.
    # @param why [String] What chose it, for the log.
    def self.apply(name, why)
      preset = find(name)
      @preset = preset
      @tone_seen = nil
      set_colors(preset.colors || game_colors)
      log("interface look #{preset.name} (#{why})")
    rescue => e
      log("interface look #{name} FAILED: #{e.class}: #{e.message}")
    end

    # Sets the style's box colors in place and counts the change.
    #
    # @param colors [Hash{Symbol => Array<Integer>}] Each color by the constant's name.
    def self.set_colors(colors)
      colors.each do |constant, (red, green, blue, alpha)|
        color = Style.const_get(constant)
        color.red, color.green, color.blue, color.alpha = red, green, blue, alpha
      end
      @serial += 1
      @skin = nil
    end

    # Puts the preset the player picked to use and keeps it in Player.ini.
    #
    # @param name [String] The preset's name.
    def self.choose(name)
      apply(name, "picked in the Mod Config")
      MGQ_Multiplayer::Player.store(SETTING, @preset.name)
    rescue => e
      log("keeping the interface look FAILED: #{e.class}: #{e.message}")
    end

    # Puts the preset Player.ini keeps to use, the first until the player picked one.
    def self.load
      stored = MGQ_Multiplayer::Player.setting(SETTING)
      apply(stored, stored ? "kept in Player.ini" : "the default")
    end

    # Works the game's look out anew once the game's window color changed, through its options, a
    # save loaded or an event. Called after every Graphics.update.
    def self.follow_game
      return unless game?
      return if window_tone == @tone_seen

      set_colors(game_colors)
      log("interface look follows the window color #{@tone_seen.join(', ')}")
    rescue => e
      log_once(:follow_game, "following the window color FAILED: #{e.class}: #{e.message}")
    end

    # Reads the game's window color.
    #
    # @return [Array<Float>] Red, green, blue and gray, all 0 before the game's data loaded.
    def self.window_tone
      tone = $game_system ? $game_system.window_tone : ($data_system && $data_system.window_tone)
      tone ? [tone.red, tone.green, tone.blue, tone.gray] : [0.0, 0.0, 0.0, 0.0]
    end

    # Works out the style's box colors from the game's window skin in the game's window color: the
    # background and its shades, the frame's line and rim, the palette's text colors.
    #
    # @return [Hash{Symbol => Array<Integer>}] Each color by the constant's name.
    def self.game_colors
      @tone_seen = window_tone
      skin = Cache.system(GAME_SKIN)
      back = toned(average(skin, *SKIN_BACK), @tone_seen)
      rim, edge = frame_line(skin)
      cursor = skin.get_pixel(SKIN_CURSOR[0] + SKIN_CURSOR[2] / 2, SKIN_CURSOR[1] + SKIN_CURSOR[3] / 2)
      picked = mix(back, [cursor.red, cursor.green, cursor.blue], PICKED_LIFT)
      heading = skin.get_pixel(*SKIN_SYSTEM_COLOR)
      title = skin.get_pixel(*SKIN_NORMAL_COLOR)
      { :BACK => back + [GAME_BACK_OPACITY], :PLATE => back + [GAME_BACK_OPACITY - 32], :PICKED => picked + [230], :FIELD => mix(back, [0, 0, 0], 0.6) + [255],
        :HEADING => [heading.red, heading.green, heading.blue, 255], :EDGE => edge + [230], :TRACK => mix(back, [255, 255, 255], 0.15) + [GAME_BACK_OPACITY + 8],
        :RIM => rim + [255], :TITLE => [title.red, title.green, title.blue, 255], :WELL => mix(back, [0, 0, 0], 0.5) + [220],
        :TAB => mix(edge, [0, 0, 0], 0.7) + [GAME_BACK_OPACITY] }
    end

    # Averages a skin's area, from samples SAMPLE_STEP apart.
    #
    # @param skin [Bitmap] The skin.
    # @param x [Integer] The area's left.
    # @param y [Integer] The area's top.
    # @param width [Integer] The area's width.
    # @param height [Integer] The area's height.
    # @return [Array<Integer>] Red, green and blue.
    def self.average(skin, x, y, width, height)
      sum = [0, 0, 0]
      count = 0
      (y...y + height).step(SAMPLE_STEP) do |row|
        (x...x + width).step(SAMPLE_STEP) do |column|
          pixel = skin.get_pixel(column, row)
          sum = [sum[0] + pixel.red, sum[1] + pixel.green, sum[2] + pixel.blue]
          count += 1
        end
      end
      sum.map { |part| (part / count).round }
    end

    # Reads the frame's rim and line down the middle of the frame square's top border: the
    # outermost pixel is the rim, the brightest the line.
    #
    # @param skin [Bitmap] The skin.
    # @return [Array(Array<Integer>, Array<Integer>)] The rim's and the line's red, green and blue.
    def self.frame_line(skin)
      column = SKIN_FRAME[0] + SKIN_FRAME[2] / 2
      pixels = (SKIN_FRAME[1]...SKIN_FRAME[1] + SKIN_BORDER).map { |row| skin.get_pixel(column, row) }.select { |pixel| pixel.alpha > 0 }
      rgb = lambda { |pixel| [pixel.red, pixel.green, pixel.blue].map { |part| part.to_i } }
      [rgb.call(pixels.first), rgb.call(pixels.max_by { |pixel| pixel.red + pixel.green + pixel.blue })]
    end

    # Colors a skin's color as a window's tone does: grays it, then adds the tone's red, green and
    # blue.
    #
    # @param color [Array<Integer>] Red, green and blue.
    # @param tone [Array<Float>] The tone's red, green, blue and gray.
    # @return [Array<Integer>] The colored red, green and blue.
    def self.toned(color, tone)
      gray = color.inject(:+) / 3.0
      color.each_with_index.map do |part, index|
        grayed = part + (gray - part) * tone[3] / 255.0
        [[grayed + tone[index], 0].max, 255].min.round
      end
    end

    # Moves one color towards another.
    #
    # @param from [Array<Integer>] Red, green and blue.
    # @param to [Array<Integer>] Red, green and blue.
    # @param share [Float] How far, from 0 to 1.
    # @return [Array<Integer>] The color between.
    def self.mix(from, to, share)
      from.zip(to).map { |a, b| (a + (b - a) * share).round }
    end

    # Hands out the window skin painted in the preset, made once per preset.
    #
    # @return [Bitmap] The skin.
    def self.skin
      @skin = paint_skin if @skin.nil? || @skin.disposed?
      @skin
    end

    # Paints a window skin in the preset: the background in BACK made opaque, since the window's
    # back_opacity carries its alpha, no pattern, the frame as a box's (Style.draw_frame) along the
    # borders, and the cursor as a picked row in its frame; the rest is the game's own skin.
    #
    # @return [Bitmap] The skin.
    def self.paint_skin
      skin = Bitmap.new(SKIN_SIDE, SKIN_SIDE)
      base = Cache.system(GAME_SKIN)
      skin.blt(0, 0, base, base.rect)
      back = Style::BACK
      skin.clear_rect(*SKIN_BACK)
      skin.fill_rect(*(SKIN_BACK + [Color.new(back.red, back.green, back.blue, 255)]))
      skin.clear_rect(*SKIN_PATTERN)
      paint_frame(skin)
      skin.clear_rect(*SKIN_CURSOR)
      skin.fill_rect(*(SKIN_CURSOR + [Style::PICKED]))
      Style.draw_frame(skin, *SKIN_CURSOR)
      skin
    end

    # Paints the frame's square of a window skin: clears its borders, keeping the scroll arrows in
    # its middle, and draws a box's frame along them.
    #
    # @param skin [Bitmap] The skin.
    def self.paint_frame(skin)
      x, y, side = SKIN_FRAME[0], SKIN_FRAME[1], SKIN_FRAME[2]
      border = SKIN_BORDER
      skin.clear_rect(x, y, side, border)
      skin.clear_rect(x, y + side - border, side, border)
      skin.clear_rect(x, y + border, border, side - 2 * border)
      skin.clear_rect(x + side - border, y + border, border, side - 2 * border)
      Style.draw_frame(skin, x, y, side, side)
    end

    # Dresses a window in the look: the preset's skin and no tone, which would tint the preset, or
    # the game's skin, whose tone the game's window color sets, for the game's look and for a game
    # window while the game's windows do not wear the look. A window of the mod also takes BACK's
    # alpha as its background's opacity. The skin changes once per change of the colors or of what
    # the window wears; the tone every time, since the game sets it on every update.
    #
    # @param window [Window] The window.
    def self.dress(window)
      return if window.disposed?

      mod = window.is_a?(Skinned)
      own = game? || !(mod || game_windows?)
      unless window.instance_variable_get(:@mgq_mp_dressed) == @serial && window.instance_variable_get(:@mgq_mp_own) == own
        window.instance_variable_set(:@mgq_mp_dressed, @serial)
        window.instance_variable_set(:@mgq_mp_own, own)
        window.windowskin = own ? Cache.system(GAME_SKIN) : skin
      end
      window.back_opacity = Style::BACK.alpha.to_i if mod
      window.tone.set(0, 0, 0, 0) unless own
    rescue => e
      log_once([:dress, window.class], "dressing a #{window.class} FAILED: #{e.class}: #{e.message}")
    end

    # Marks a window of the mod, which takes BACK's alpha as its background's opacity besides the
    # look every window wears (see dress).
    module Skinned
    end

    # Offers the preset and the look on the game's windows as rows of the Mod Config, kept in
    # Player.ini.
    def self.add_option
      added = MGQ_MpUi.add_option(OPTION, OPTION_NAME, OPTION_HELP, lambda { names }, lambda { current.name }, lambda { |name| choose(name) })
      MGQ_MpUi.add_option(GAME_WINDOWS_OPTION, GAME_WINDOWS_OPTION_NAME, GAME_WINDOWS_OPTION_HELP, lambda { [ON, OFF] },
                          lambda { game_windows? ? ON : OFF }, lambda { |value| dress_game_windows(value == ON) })
      log(added ? "added the interface look to the Mod Config" : "no interface look in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
    end
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # Every window, the game's and the mod's, wears the look as it is made and on every update,
  # which follows a change of the look and takes the tone back from the game's window color.
  MGQ_MpHooks.after(Window_Base, :initialize, "theme") { MGQ_MpUi::Theme.dress(self) }
  MGQ_MpHooks.after(Window_Base, :update, "theme") { MGQ_MpUi::Theme.dress(self) }
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "theme") { MGQ_MpUi::Theme.follow_game }
  MGQ_MpUi::Theme.load
  MGQ_MpUi::Theme.add_option
rescue => e
  MGQ_MpUi::Theme.log("start FAILED: #{e.class}: #{e.message}")
end
