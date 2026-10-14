#----------------------------------------------------------------
#  rgss.rb
#
#  Changelog:
#      Paulinchen  2026-10-14: Created
#
#----------------------------------------------------------------

# The classes and modules RGSS3 builds into Game.exe, without a screen, sound or keyboard: the
# value classes behave as in the game, everything that draws or plays keeps its state and shows
# nothing.

# The error RGSS raises for a disposed object.
class RGSSError < StandardError; end

# The exception RGSS raises when F12 resets the game.
class RGSSReset < Exception; end

# A rectangle.
class Rect
  attr_accessor :x, :y, :width, :height

  # Creates the rectangle.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  # @param height [Integer] The height.
  def initialize(x = 0, y = 0, width = 0, height = 0)
    set(x, y, width, height)
  end

  # Sets every edge, or copies another rectangle.
  #
  # @param args [Array] Four numbers or one Rect.
  # @return [Rect] The rectangle.
  def set(*args)
    args = [args[0].x, args[0].y, args[0].width, args[0].height] if args.size == 1
    @x, @y, @width, @height = args
    self
  end

  # Sets every edge to 0.
  #
  # @return [Rect] The rectangle.
  def empty
    set(0, 0, 0, 0)
  end

  # Packs the rectangle as RGSS does.
  #
  # @param _level [Integer] The depth Marshal passes.
  # @return [String] The bytes.
  def _dump(_level)
    [@x, @y, @width, @height].pack("l4")
  end

  # Unpacks a rectangle RGSS packed.
  #
  # @param bytes [String] The bytes.
  # @return [Rect] The rectangle.
  def self._load(bytes)
    new(*bytes.unpack("l4"))
  end
end

# A color of four channels from 0 to 255.
class Color
  attr_reader :red, :green, :blue, :alpha

  # Creates the color.
  #
  # @param args [Array] Three or four channels, one Color, or nothing for transparent black.
  def initialize(*args)
    args.empty? ? set(0, 0, 0, 0) : set(*args)
  end

  # Sets the channels, or copies another color.
  #
  # @param args [Array] Three or four channels or one Color.
  # @return [Color] The color.
  def set(*args)
    args = [args[0].red, args[0].green, args[0].blue, args[0].alpha] if args.size == 1
    self.red, self.green, self.blue = args[0], args[1], args[2]
    self.alpha = args[3] || 255
    self
  end

  %w[red green blue alpha].each do |channel|
    define_method("#{channel}=") { |value| instance_variable_set("@#{channel}", value.to_f.clamp(0.0, 255.0)) }
  end

  # Packs the color as RGSS does.
  #
  # @param _level [Integer] The depth Marshal passes.
  # @return [String] The bytes.
  def _dump(_level)
    [@red, @green, @blue, @alpha].pack("E4")
  end

  # Unpacks a color RGSS packed.
  #
  # @param bytes [String] The bytes.
  # @return [Color] The color.
  def self._load(bytes)
    new(*bytes.unpack("E4"))
  end
end

# A tone of three channels from -255 to 255 and a gray from 0 to 255.
class Tone
  attr_reader :red, :green, :blue, :gray

  # Creates the tone.
  #
  # @param args [Array] Three or four channels, one Tone, or nothing for no change.
  def initialize(*args)
    args.empty? ? set(0, 0, 0, 0) : set(*args)
  end

  # Sets the channels, or copies another tone.
  #
  # @param args [Array] Three or four channels or one Tone.
  # @return [Tone] The tone.
  def set(*args)
    args = [args[0].red, args[0].green, args[0].blue, args[0].gray] if args.size == 1
    self.red, self.green, self.blue = args[0], args[1], args[2]
    self.gray = args[3] || 0
    self
  end

  %w[red green blue].each do |channel|
    define_method("#{channel}=") { |value| instance_variable_set("@#{channel}", value.to_f.clamp(-255.0, 255.0)) }
  end

  # Sets the gray.
  #
  # @param value [Numeric] The gray.
  def gray=(value)
    @gray = value.to_f.clamp(0.0, 255.0)
  end

  # Packs the tone as RGSS does.
  #
  # @param _level [Integer] The depth Marshal passes.
  # @return [String] The bytes.
  def _dump(_level)
    [@red, @green, @blue, @gray].pack("E4")
  end

  # Unpacks a tone RGSS packed.
  #
  # @param bytes [String] The bytes.
  # @return [Tone] The tone.
  def self._load(bytes)
    new(*bytes.unpack("E4"))
  end
end

# A table of 16-bit integers of up to three dimensions.
class Table
  attr_reader :xsize, :ysize, :zsize

  # Creates the table, filled with 0.
  #
  # @param xsize [Integer] The first dimension.
  # @param ysize [Integer] The second dimension, 1 when left out.
  # @param zsize [Integer] The third dimension, 1 when left out.
  def initialize(xsize, ysize = nil, zsize = nil)
    @dim = zsize ? 3 : (ysize ? 2 : 1)
    @xsize, @ysize, @zsize = xsize, ysize || 1, zsize || 1
    @data = Array.new(@xsize * @ysize * @zsize, 0)
  end

  # Changes the dimensions, keeping the values that still fit.
  #
  # @param xsize [Integer] The first dimension.
  # @param ysize [Integer] The second dimension.
  # @param zsize [Integer] The third dimension.
  def resize(xsize, ysize = nil, zsize = nil)
    old = self.class.new(@xsize, @ysize, @zsize).tap { |t| t.instance_variable_set(:@data, @data) }
    initialize(xsize, ysize, zsize)
    [@xsize, old.xsize].min.times do |x|
      [@ysize, old.ysize].min.times do |y|
        [@zsize, old.zsize].min.times { |z| self[x, y, z] = old[x, y, z] }
      end
    end
  end

  # Reads a value.
  #
  # @param x [Integer] The first index.
  # @param y [Integer] The second index.
  # @param z [Integer] The third index.
  # @return [Integer, nil] The value, nil outside the table.
  def [](x, y = 0, z = 0)
    return nil if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @data[x + (y + z * @ysize) * @xsize]
  end

  # Writes a value, cut to 16 bits; outside the table it does nothing.
  #
  # @param args [Array] The indexes and then the value.
  def []=(*args)
    value = args.pop
    x, y, z = args[0], args[1] || 0, args[2] || 0
    return if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @data[x + (y + z * @ysize) * @xsize] = [[value.to_i, -32768].max, 32767].min
  end

  # Packs the table as RGSS does.
  #
  # @param _level [Integer] The depth Marshal passes.
  # @return [String] The bytes.
  def _dump(_level)
    [@dim, @xsize, @ysize, @zsize, @data.size].pack("l5") + @data.pack("s*")
  end

  # Unpacks a table RGSS packed.
  #
  # @param bytes [String] The bytes.
  # @return [Table] The table.
  def self._load(bytes)
    dim, xsize, ysize, zsize, size = bytes.unpack("l5")
    table = allocate
    table.instance_variable_set(:@dim, dim)
    table.instance_variable_set(:@xsize, xsize)
    table.instance_variable_set(:@ysize, ysize)
    table.instance_variable_set(:@zsize, zsize)
    table.instance_variable_set(:@data, bytes[20, size * 2].unpack("s*"))
    table
  end
end

# A font; it only keeps its settings.
class Font
  class << self
    attr_accessor :default_name, :default_size, :default_bold, :default_italic, :default_shadow,
                  :default_outline, :default_color, :default_out_color
  end
  self.default_name = ["VL Gothic"]
  self.default_size = 24
  self.default_bold = false
  self.default_italic = false
  self.default_shadow = false
  self.default_outline = true
  self.default_color = Color.new(255, 255, 255, 255)
  self.default_out_color = Color.new(0, 0, 0, 128)

  attr_accessor :name, :size, :bold, :italic, :outline, :shadow, :color, :out_color

  # Tells that every font exists.
  #
  # @param _name [String] The font's name.
  # @return [Boolean] Always true.
  def self.exist?(_name)
    true
  end

  # Creates the font with the defaults.
  #
  # @param name [String, Array] The font's name.
  # @param size [Integer] The size.
  def initialize(name = Font.default_name, size = Font.default_size)
    @name, @size = name, size
    @bold, @italic = Font.default_bold, Font.default_italic
    @outline, @shadow = Font.default_outline, Font.default_shadow
    @color, @out_color = Font.default_color.dup, Font.default_out_color.dup
  end
end

# What every object that RGSS frees by hand shares.
module Disposable
  # Frees the object.
  def dispose
    @disposed = true
  end

  # Tells whether the object was freed.
  #
  # @return [Boolean] Whether it was.
  def disposed?
    @disposed == true
  end
end

# A picture; it keeps its size and font and draws nothing.
class Bitmap
  include Disposable

  # The size a bitmap read from a file gets, since no file is read.
  FILE_SIZE = [32, 32].freeze

  attr_accessor :font
  attr_reader :width, :height

  # Creates the bitmap.
  #
  # @param args [Array] A width and a height, or a file name.
  def initialize(*args)
    @width, @height = args[0].is_a?(String) ? FILE_SIZE : [args[0].to_i, args[1].to_i]
    @font = Font.new
  end

  # The bitmap's whole area.
  #
  # @return [Rect] The rectangle.
  def rect
    Rect.new(0, 0, @width, @height)
  end

  # Tells the size a text would take, guessing half the font's size per character.
  #
  # @param text [Object] The text.
  # @return [Rect] The rectangle it would take.
  def text_size(text)
    Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size)
  end

  # Reads a pixel, always transparent.
  #
  # @return [Color] The pixel's color.
  def get_pixel(*)
    Color.new(0, 0, 0, 0)
  end

  %i[blt stretch_blt fill_rect gradient_fill_rect clear clear_rect set_pixel hue_change blur
     radial_blur draw_text save].each { |name| define_method(name) { |*| nil } }
end

# An area of the screen; it only keeps its settings.
class Viewport
  include Disposable

  attr_accessor :rect, :visible, :z, :ox, :oy, :color, :tone

  # Creates the viewport.
  #
  # @param args [Array] Nothing, a Rect, or four numbers.
  def initialize(*args)
    @rect = args.size == 1 ? args[0] : Rect.new(*args)
    @visible, @z, @ox, @oy = true, 0, 0, 0
    @color, @tone = Color.new, Tone.new
  end

  # Does nothing, as nothing flashes.
  def flash(*); end

  # Does nothing, as nothing is drawn.
  def update; end
end

# A picture on the screen; it keeps its settings.
class Sprite
  include Disposable

  attr_accessor :bitmap, :src_rect, :viewport, :visible, :x, :y, :z, :ox, :oy, :zoom_x, :zoom_y,
                :angle, :wave_amp, :wave_length, :wave_speed, :wave_phase, :mirror, :bush_depth,
                :bush_opacity, :opacity, :blend_type, :color, :tone

  # Creates the sprite.
  #
  # @param viewport [Viewport, nil] The viewport.
  def initialize(viewport = nil)
    @viewport, @src_rect = viewport, Rect.new
    @visible, @mirror = true, false
    @x = @y = @z = @ox = @oy = @angle = @bush_depth = @blend_type = 0
    @wave_amp = @wave_length = @wave_speed = @wave_phase = 0
    @zoom_x = @zoom_y = 1.0
    @bush_opacity = 128
    @opacity = 255
    @color, @tone = Color.new, Tone.new
  end

  # Sets the bitmap, and the source rectangle to all of it.
  #
  # @param bitmap [Bitmap, nil] The bitmap.
  def bitmap=(bitmap)
    @bitmap = bitmap
    @src_rect = bitmap ? bitmap.rect : Rect.new
  end

  # The width shown.
  #
  # @return [Integer] The width.
  def width
    @src_rect.width
  end

  # The height shown.
  #
  # @return [Integer] The height.
  def height
    @src_rect.height
  end

  # Does nothing, as nothing flashes.
  def flash(*); end

  # Does nothing, as nothing is drawn.
  def update; end
end

# A repeated picture on the screen; it keeps its settings.
class Plane
  include Disposable

  attr_accessor :bitmap, :viewport, :visible, :z, :ox, :oy, :zoom_x, :zoom_y, :opacity,
                :blend_type, :color, :tone

  # Creates the plane.
  #
  # @param viewport [Viewport, nil] The viewport.
  def initialize(viewport = nil)
    @viewport, @visible = viewport, true
    @z = @ox = @oy = @blend_type = 0
    @zoom_x = @zoom_y = 1.0
    @opacity = 255
    @color, @tone = Color.new, Tone.new
  end
end

# A window on the screen; it keeps its settings, and its openness changes at once.
class Window
  include Disposable

  attr_accessor :windowskin, :contents, :cursor_rect, :viewport, :active, :visible,
                :arrows_visible, :pause, :x, :y, :width, :height, :z, :ox, :oy, :padding,
                :padding_bottom, :opacity, :back_opacity, :contents_opacity, :tone
  attr_reader :openness

  # Creates the window.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  # @param height [Integer] The height.
  def initialize(x = 0, y = 0, width = 0, height = 0)
    @x, @y, @width, @height = x, y, width, height
    @contents = Bitmap.new(1, 1)
    @cursor_rect = Rect.new
    @active = @visible = @arrows_visible = true
    @pause = false
    @z = @ox = @oy = 0
    @padding = @padding_bottom = 12
    @opacity = @back_opacity = @contents_opacity = 255
    @openness = 255
    @tone = Tone.new
  end

  # Sets the openness.
  #
  # @param value [Integer] The openness, 0 to 255.
  def openness=(value)
    @openness = value.to_i.clamp(0, 255)
  end

  # Tells whether the window is fully open.
  #
  # @return [Boolean] Whether it is.
  def open?
    @openness == 255
  end

  # Tells whether the window is fully closed.
  #
  # @return [Boolean] Whether it is.
  def close?
    @openness == 0
  end

  # Moves and resizes the window.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  # @param height [Integer] The height.
  def move(x, y, width, height)
    @x, @y, @width, @height = x, y, width, height
  end

  # Does nothing, as nothing is drawn.
  def update; end
end

# The screen: it counts frames and never waits.
module Graphics
  @frame_rate = 60
  @frame_count = 0
  @brightness = 255
  @width = 544
  @height = 416

  class << self
    attr_accessor :frame_rate, :frame_count, :brightness
    attr_reader :width, :height

    # Counts a frame and runs what a test or the server hooked in.
    def update
      @frame_count += 1
    end

    # Counts frames without waiting.
    #
    # @param duration [Integer] The frames.
    def wait(duration)
      duration.times { update }
    end

    # Changes the screen's size.
    #
    # @param width [Integer] The width.
    # @param height [Integer] The height.
    def resize_screen(width, height)
      @width, @height = width, height
    end

    # Takes a picture of the screen, an empty one.
    #
    # @return [Bitmap] The picture.
    def snap_to_bitmap
      Bitmap.new(@width, @height)
    end

    %i[fadeout fadein freeze transition frame_reset play_movie].each { |name| define_method(name) { |*| nil } }
  end
end

# The keyboard and gamepad: nothing is ever pressed unless a driver says so.
module Input
  %i[DOWN LEFT RIGHT UP A B C X Y Z L R SHIFT CTRL ALT F5 F6 F7 F8 F9].each { |key| const_set(key, key) }

  @pressed = {}
  @triggered = {}

  class << self
    # Takes the keys a driver pressed for the next frame.
    #
    # @param triggered [Array<Symbol>] The keys pressed this frame.
    def drive(*triggered)
      @next = triggered
    end

    # Starts a frame: the driven keys count as pressed and triggered for it.
    def update
      keys = @next || []
      @next = nil
      @triggered = keys.to_h { |key| [key, true] }
      @pressed = @triggered
    end

    # Tells whether a key is held.
    #
    # @param key [Symbol] The key.
    # @return [Boolean] Whether it is.
    def press?(key)
      @pressed[key] == true
    end

    # Tells whether a key was pressed this frame.
    #
    # @param key [Symbol] The key.
    # @return [Boolean] Whether it was.
    def trigger?(key)
      @triggered[key] == true
    end

    # Tells whether a key repeats this frame.
    #
    # @param key [Symbol] The key.
    # @return [Boolean] Whether it does.
    def repeat?(key)
      @triggered[key] == true
    end

    # The direction held, of four.
    #
    # @return [Integer] Always 0.
    def dir4
      0
    end

    # The direction held, of eight.
    #
    # @return [Integer] Always 0.
    def dir8
      0
    end
  end
end

# The sound: nothing plays.
module Audio
  class << self
    %i[setup_midi bgm_play bgm_stop bgm_fade bgm_pos bgs_play bgs_stop bgs_fade bgs_pos me_play
       me_stop me_fade se_play se_stop].each { |name| define_method(name) { |*| 0 } }
  end
end

# A call into a Windows DLL: every call answers 0.
class Win32API
  # Creates the call.
  def initialize(*); end

  # Answers 0.
  #
  # @return [Integer] Always 0.
  def call(*)
    0
  end
  alias Call call
end

# The block the game's last script hands to rgss_main, kept instead of run.
$rgss_main_block = nil

# Keeps the game's main loop instead of running it.
def rgss_main(&block)
  $rgss_main_block = block
end

# Does nothing, as there is no screen to stop on.
def rgss_stop; end

# Reads a data file of the game.
#
# @param path [String] The path, from the game folder.
# @return [Object] The data.
def load_data(path)
  File.open(path.tr("\\", "/"), "rb") { |file| Marshal.load(file) }
end

# Writes a data file of the game.
#
# @param object [Object] The data.
# @param path [String] The path, from the game folder.
def save_data(object, path)
  File.open(path.tr("\\", "/"), "wb") { |file| Marshal.dump(object, file) }
end

# Writes a message box's text to the log instead.
#
# @param args [Array] The text.
def msgbox(*args)
  $stderr.puts("[msgbox] #{args.join}")
end

# Writes a message box's values to the log instead.
#
# @param args [Array] The values.
def msgbox_p(*args)
  $stderr.puts("[msgbox] #{args.map(&:inspect).join("\n")}")
end
