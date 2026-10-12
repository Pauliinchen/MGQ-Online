#----------------------------------------------------------------
#  ui_theme.rbx
#
#  Changelog:
#      Paulinchen  2026-10-12: Gave the tabs not picked the edge's color, darkened
#                            - Added the scrollbar track's color
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# The interface presets: the colors every box, frame, gauge and window of the mod is drawn in, the
# player's pick kept in Player.ini and offered as a row of the Mod Config. A preset sets the
# style's box colors in place (see MGQ_MpUi::Style), and the mod's windows take a window skin
# painted in them (see Skinned).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpUi
  module Theme
    extend MGQ_MpLog

    # What starts this script's lines in Multiplayer InGame.log.
    LOG_TAG = "theme"

    # One preset: its name and the color of each of the style's box colors, by the constant's name,
    # as red, green, blue and alpha.
    Preset = Struct.new(:name, :colors)

    # The presets, the first the one until the player picks another: Monarch, the raid boss bar's
    # maroon with a gold edge in a black rim, and Legacy, the chat's black glass with a grey edge, the
    # mod's look before the presets.
    PRESETS = [
      Preset.new("Monarch", { :BACK => [36, 10, 14, 235], :PLATE => [36, 10, 14, 200], :PICKED => [120, 36, 52, 235], :FIELD => [20, 6, 8, 255],
                              :HEADING => [240, 204, 130, 255], :EDGE => [200, 164, 96, 230], :TRACK => [84, 50, 38, 240], :RIM => [0, 0, 0, 255],
                              :TITLE => [255, 224, 140, 255], :WELL => [36, 10, 14, 235], :TAB => [100, 78, 40, 235] }),
      Preset.new("Legacy", { :BACK => [0, 0, 0, 170], :PLATE => [0, 0, 0, 150], :PICKED => [48, 96, 176, 220], :FIELD => [12, 16, 28, 255],
                             :HEADING => [160, 200, 255, 255], :EDGE => [140, 140, 140, 220], :TRACK => [48, 48, 48, 200], :RIM => [0, 0, 0, 0],
                             :TITLE => [255, 255, 255, 255], :WELL => [0, 0, 0, 220], :TAB => [64, 64, 64, 170] }),
    ]

    # The setting in Player.ini that keeps the preset's name.
    SETTING = "ui_preset"

    # The Mod Config row's key.
    OPTION = :mp_ui_preset

    # The Mod Config row's name and help.
    OPTION_NAME = "Interface Look"
    OPTION_HELP = "The colors of the boxes, frames and windows of the mod: Monarch is the raid boss bar's maroon\n" \
                  "with a gold edge, Legacy the black glass with a grey edge the mod had before."

    # Side of a window skin, in pixels.
    SKIN_SIDE = 128

    # Where a window skin keeps its parts: the background stretched over the window, the pattern
    # tiled over it, the frame and the cursor. The frame's middle holds the scroll arrows, which the
    # game's own skin lends, as it lends the pause sign and the text colors.
    SKIN_BACK = [0, 0, 64, 64]
    SKIN_PATTERN = [0, 64, 64, 64]
    SKIN_FRAME = [64, 0, 64, 64]
    SKIN_CURSOR = [64, 64, 32, 32]

    # Pixels of the frame's square along its sides that a window draws its borders from; its middle
    # holds the scroll arrows.
    SKIN_BORDER = 16

    @preset = PRESETS.first

    # Counts every change of the preset, which whoever keeps a picture drawn in its colors compares.
    @serial = 0

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

    # Tells how often the preset changed, so a picture drawn in its colors knows to draw anew.
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
      preset.colors.each do |constant, (red, green, blue, alpha)|
        color = Style.const_get(constant)
        color.red, color.green, color.blue, color.alpha = red, green, blue, alpha
      end
      @preset = preset
      @serial += 1
      @skin = nil
      log("interface look #{preset.name} (#{why})")
    rescue => e
      log("interface look #{name} FAILED: #{e.class}: #{e.message}")
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
      base = Cache.system("Window")
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

    # Dresses a window in the preset: its skin, BACK's alpha as the background's opacity, and no
    # tone of the game's window color, which would tint the preset.
    #
    # @param window [Window] The window.
    def self.dress(window)
      return if window.disposed?

      window.windowskin = skin
      window.back_opacity = Style::BACK.alpha.to_i
      window.tone.set(0, 0, 0, 0)
    rescue => e
      log_once([:dress, window.class], "dressing a #{window.class} FAILED: #{e.class}: #{e.message}")
    end

    # Makes a window class of the mod wear the preset: included into the class, its windows are
    # dressed once made and again whenever the preset changes.
    module Skinned
      # Makes the window as its class does, then dresses it.
      #
      # @param args [Array] The arguments of the class's initialize.
      def initialize(*args, &block)
        super(*args, &block)
        @mgq_mp_dressed = Theme.serial
        Theme.dress(self)
      end

      # Updates the window as its class does, dressing it anew once the preset changed.
      def update
        super
        return if @mgq_mp_dressed == Theme.serial

        @mgq_mp_dressed = Theme.serial
        Theme.dress(self)
      end

      # Keeps the window untinted, in place of the game's window color.
      def update_tone
        tone.set(0, 0, 0, 0)
      end
    end

    # Offers the preset as a row of the Mod Config, kept in Player.ini.
    def self.add_option
      added = MGQ_MpUi.add_option(OPTION, OPTION_NAME, OPTION_HELP, lambda { names }, lambda { current.name }, lambda { |name| choose(name) })
      log(added ? "added the interface look to the Mod Config" : "no interface look in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
    end
  end
end

begin
  MGQ_MpUi::Theme.load
  MGQ_MpUi::Theme.add_option
rescue => e
  MGQ_MpUi::Theme.log("start FAILED: #{e.class}: #{e.message}")
end
