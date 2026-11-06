#----------------------------------------------------------------
#  components_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Stood in for the room of a zone's parts
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# Stand-ins for the game's pictures as far as the Mod Framework's components measure their texts,
# faces and figures, and helpers that read what a screen's components hold. The framework's own
# tests cover how its components lay out and draw; a screen's tests read the components it builds
# and what it sets on them.

require_relative "support"

# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height) unless defined?(Rect)

# The game's font.
Font = Struct.new(:size, :color, :bold, :outline, :out_color, :name, :italic) unless defined?(Font)

# The game's picture, as far as the framework measures texts on it: half the font's size a
# character, as high as the font.
unless defined?(Bitmap)
  class Bitmap
    attr_reader :width, :height, :font

    # Makes an empty picture in a font of 24.
    #
    # @param width [Integer] Its width.
    # @param height [Integer] Its height.
    def initialize(width = 1, height = 1)
      @width = width
      @height = height
      @font = Font.new(24, Color.new(255, 255, 255))
    end

    # Tells the picture's whole rectangle.
    #
    # @return [Rect] The rectangle.
    def rect
      Rect.new(0, 0, @width, @height)
    end

    # Measures a text at half the font's size a character.
    #
    # @param text [String] The text.
    # @return [Rect] Its size.
    def text_size(text)
      Rect.new(0, 0, text.to_s.size * @font.size.to_i / 2, @font.size.to_i)
    end

    # Answers that every pixel is see-through but a figure's, see Sheet.
    #
    # @return [Color] The color.
    def get_pixel(_x, _y)
      Color.new(0, 0, 0, 0)
    end

    # Forgets nothing, since nothing is drawn.
    def clear; end

    # Frees the picture.
    def dispose
      @disposed = true
    end

    # Tells whether the picture was freed.
    #
    # @return [Boolean] Whether it was.
    def disposed?
      @disposed ? true : false
    end
  end
end

# A sheet of eight characters in frames of 32 by 48, every pixel of each frame's middle 24 by 36
# opaque, so a figure is that much.
class HudSheet < Bitmap
  # Makes the sheet.
  def initialize
    super(384, 384)
  end

  # Answers a pixel's color: opaque in a frame's middle, see-through elsewhere.
  #
  # @param x [Integer] The pixel's column.
  # @param y [Integer] The pixel's row.
  # @return [Color] The color.
  def get_pixel(x, y)
    Color.new(0, 0, 0, (x % 32).between?(4, 27) && (y % 48).between?(12, 47) ? 255 : 0)
  end
end

# The game's cache of faces, character sheets and system pictures: a face sheet of 384 by 384,
# HudSheet, and an empty picture for the icon set.
module Cache
  # Hands out a picture of Graphics/System.
  #
  # @param _name [String] Its file.
  # @return [Bitmap] The picture.
  def self.system(_name)
    @system ||= Bitmap.new(512, 512)
  end

  # Hands out a face sheet.
  #
  # @param _name [String] Its file.
  # @return [Bitmap] The sheet.
  def self.face(_name)
    @face ||= Bitmap.new(384, 384)
  end

  # Hands out a character sheet.
  #
  # @param _name [String] Its file.
  # @return [HudSheet] The sheet.
  def self.character(_name)
    @sheet ||= HudSheet.new
  end
end

# Lists a component and every part inside it, in their order.
#
# @param component [Mod_Framework::UI::Component] The component.
# @return [Array<Mod_Framework::UI::Component>] It and its parts.
def parts_of(component)
  [component] + Array(component.children).map { |child| parts_of(child) }.flatten
end

# Lists the parts of a kind inside a component.
#
# @param component [Mod_Framework::UI::Component] The component.
# @param kind [Class] The kind, such as Mod_Framework::UI::Label.
# @return [Array<Mod_Framework::UI::Component>] The parts.
def parts_of_kind(component, kind)
  parts_of(component).select { |part| part.is_a?(kind) }
end

# Lists the texts of the labels and buttons inside a component, in their order, the empty ones
# left out.
#
# @param component [Mod_Framework::UI::Component] The component.
# @return [Array<String>] The texts.
def texts_of(component)
  parts_of(component).select { |part| part.is_a?(Mod_Framework::UI::Label) || part.is_a?(Mod_Framework::UI::Button) }.map { |part| part.text.to_s }.reject { |text| text.empty? }
end

# Finds the label or button inside a component with a text.
#
# @param component [Mod_Framework::UI::Component] The component.
# @param text [String] The text.
# @return [Mod_Framework::UI::Component, nil] The part, nil for none.
def part_with_text(component, text)
  parts_of(component).find { |part| (part.is_a?(Mod_Framework::UI::Label) || part.is_a?(Mod_Framework::UI::Button)) && part.text.to_s == text }
end

# Tells whether a root of the framework hides now, by its :hidden_in and :hide_while.
#
# @param root [Mod_Framework::UI::Component] The root.
# @return [Boolean] Whether it hides.
def hidden_root?(root)
  root.send(:hidden_now?)
end

# Tells the room the framework answers a zone's parts take, which C# lays out in the game; a test
# sets it in $docked_room by zone.
$docked_room = {}
Mod_Framework::UI::Layout.define_singleton_method(:docked_room) { |dock| $docked_room[dock].to_i }
Mod_Framework::UI::Layout.define_singleton_method(:room) { |zone| $docked_room[zone].to_i }
