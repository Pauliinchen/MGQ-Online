#----------------------------------------------------------------
#  boxes_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Dropped the stand-ins of the keys, the mouse and the held buttons, which no check reads
#                            - Reached the Mod Framework's engine under its own name
#                            - Compared a player's color with the color the UI layer reads now
#                            - Left the list box to the world screen's tests and the in-game suite, checking a player's color names
#                            - Dropped the info strip's checks with the strip
#      Paulinchen  2026-11-05: Read the scripts' clock from $frame
#      Paulinchen  2026-11-01: Dropped the checks of the list windows' mouse wheel and scrollbar, which no screen uses any more
#                            - Renamed from ui_boxes_test.rb and covered the list box and the info strip on the Mod Framework's components
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers what MGQ Online's screens keep of their own in ui_online.rbx: the color of a player. The
# list box is checked through the world screen that opens it and in the in-game suite; the
# framework's components, question box and message are its own tests'.

require_relative "bridge_support"

# Stand-ins for the game and the mod's base script.
$log = []
$sounds = []
$frame = 0
$player_ini = {}
# The mod's base script: the log in $log and Player.ini in $player_ini.
module MGQ_Multiplayer
  # The mod's log, kept in $log.
  module Log; def self.write(message); $log << message; end; end
  # Player.ini, kept in $player_ini.
  module Player
    # A setting of Player.ini.
    def self.setting(key); $player_ini[key]; end
    # Stores a setting.
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
    # Forgets a setting.
    def self.forget(key); $player_ini.delete(key); true; end
  end
end
# Mod Config with its Return row alone.
module NWConst; module Config; MOD_CONTENTS = [{ :key => :return }]; end; end
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# A font that keeps one color of its own, as RGSS does: color hands out that color and color=
# copies a color's values into it.
class Font < Struct.new(:size, :color, :bold, :outline, :out_color)
  # Copies a color's values into the font's own color.
  #
  # @param value [Color] The color.
  def color=(value)
    self[:color] ||= Color.new
    self[:color].red, self[:color].green, self[:color].blue, self[:color].alpha = value.red, value.green, value.blue, value.alpha
  end
end
# A picture that records its texts, its fills and how many outline copies it drew.
class Bitmap
  # Its size, its font, the texts and fills drawn, the outline copies and whether a text was drawn
  # with the font's own outline on.
  attr_reader :width, :height, :font, :texts, :fills, :outlines, :outlined_twice
  # Creates an empty picture in a white font of 24 without an outline.
  def initialize(width, height); @width = width; @height = height; @font = Font.new(24, Color.new(255, 255, 255, 255), false, false, nil); @texts = []; @fills = []; @outlines = 0; end
  # The picture's whole rectangle.
  def rect; Rect.new(0, 0, @width, @height); end
  # Measures a text at half the font's size a character.
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  # Records a text drawn, or counts it as an outline copy when drawn in the outline's color.
  #
  # @param x [Integer] Its left.
  # @param y [Integer] Its top.
  # @param width [Integer] Its width.
  # @param height [Integer] Its height.
  # @param text [String] The text.
  # @param align [Integer] Its alignment.
  def draw_text(x, y, width, height, text, align = 0)
    @outlined_twice = true if @font.outline
    if @font.color == Mod_Framework::UI::Engine::Style::OUTLINE
      @outlines += 1
    else
      @texts << [x, y, text, @font.size, @font.color.dup, align]
    end
  end
  # Records a fill with its rectangle and color.
  #
  # @param args [Array] A rectangle and a color, or x, y, width, height and a color.
  def fill_rect(*args)
    x, y, w, h, color = args[0].is_a?(Rect) ? [args[0].x, args[0].y, args[0].width, args[0].height, args[1]] : args
    @fills << [x, y, w, h, color]
  end
  # Forgets the texts, fills and outline copies.
  def clear; @texts.clear; @fills.clear; @outlines = 0; end
  # Frees the picture.
  def dispose; @disposed = true; end
  # Whether the picture was freed.
  def disposed?; @disposed ? true : false; end
end
# The game's screen of 640 by 480 pixels, at frame $frame.
module Graphics; def self.width; 640; end; def self.height; 480; end; def self.update; end; end
clock_from { $frame }
# The game's system sounds: each one played is added to $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# The game's scene manager, whose scene is $scene.
module SceneManager; def self.scene; $scene; end; end
# The game's scene base, which does nothing.
class Scene_Base; def update; end; def start; end; end
# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The open world, whose player is me.
module MGQ_MpOverworldSync; module Me; def self.id; "me"; end; end; end
# The party p1.
module MGQ_MpCoop; module Party; def self.member?(state); state["party"] == "p1"; end; end; end
$scene = Scene_Base.new

load_script "core_hotkeys"
load_script "ui_online"

own, ally, text = [:own, :ally, :text].map { |name| Mod_Framework::UI.color_now(name) }

# The color of a player.
colors = MGQ_MpPlayerColor
# Another player: their seat, their state and whether they are in the party.
Peer = Struct.new(:seat, :state, :member)
peer = Peer.new(2, { "id" => "p-other", "name" => "Player A" }, false)
mate = Peer.new(3, { "id" => "p-mate" }, true)
check("the player themself is in the own color", [colors.of(:me), colors.of("me"), colors.of(peer, nil, true), colors.label(:me)], [own, own, own, "own"])
check("a party member is in the ally color", [colors.of(mate), colors.of(peer, true), colors.of({ "id" => "x", "party" => "p1" }), colors.label(mate)], [ally, ally, ally, "member"])
check("anyone else is plain text, whatever their id", [colors.of(peer), colors.of("p-other"), colors.of({ "id" => "p-other", "party" => "p2" }), colors.label(peer), colors.const_defined?(:PALETTE)],
      [text, text, text, "plain", false])
check("nobody reads as plain text, without raising", [colors.of(""), colors.of(Object.new), colors.of(nil), colors.label("")], [text, text, text, "plain"])

check("the UI layer takes a player's color by MGQ Online's names", [colors.role(:me), colors.role(mate), colors.role(peer)], [:mgq_online_own, :mgq_online_member, :text])
