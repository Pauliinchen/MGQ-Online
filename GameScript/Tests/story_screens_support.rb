#----------------------------------------------------------------
#  story_screens_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Found a screen's component of the UI layer
#      Paulinchen  2026-11-05: Loaded the fixed answers of the story's telling instead of the stand-in of the choices' rules
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# The game around coop_choices.rbx for the tests of its two screens, the story's choices and the
# question a replay asks: the map, the menu scenes the Mod Framework opens its windows in, the
# sounds, and the framework's bridge on a FakeBridge, so the screens are the framework's real
# windows. A test steps into the menu scene the framework called with enter_menu and plays the
# player on the window's parts with their events.

require_relative "bridge_support"
require_relative "telling_support"

# The game's rectangle and font, and a picture that measures texts at half the font's size a
# character, as far as the framework's parts measure their texts.
Rect = Struct.new(:x, :y, :width, :height) unless defined?(Rect)
Font = Struct.new(:size, :color, :bold, :outline, :out_color, :name, :italic) unless defined?(Font)
class Bitmap
  attr_reader :width, :height, :font
  def initialize(width, height); @width, @height, @font = width, height, Font.new(24); end
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size.to_i / 2, @font.size.to_i); end
  def dispose; @disposed = true; end
  def disposed?; @disposed ? true : false; end
end
# The players' wheel and notices of ui_actions.rbx.
module MGQ_MpActions; LINE_COLOR = :line_color; def self.offer(_offers); end; end
# The game's base scene.
class Scene_Base; def start; end; def update; end; def terminate; end; end
# The game's map scene, which ends when the player leaves it for a menu or a battle.
class Scene_Map < Scene_Base; end
# The base of the game's menu scenes: back goes to the map.
class Scene_MenuBase < Scene_Base; def return_scene; SceneManager.goto_map; end; end
# The game's map and its data manager, whose methods the script hooks.
class Game_Map; def update; end; end
module DataManager; def self.extract_save_contents(_contents); end; def self.setup_new_game; end; end
# The game's scene manager: the scene in front in $scene, the scenes called kept in $scenes.
module SceneManager
  # Hands out the scene in front.
  def self.scene; $scene; end
  # Calls a scene, which is in front at once and starts in a later frame, as in the game.
  def self.call(scene); ($scenes ||= []) << scene; $scene = scene.new; end
  # Goes back to the map, as a menu's return does.
  def self.goto_map; $scene = Scene_Map.new; end
end
# The game's system sounds: each one played is kept in $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |name| define_singleton_method("play_#{name}") { ($sounds ||= []) << name } }; end
# The world: the player stands free on the map while $free says so, and the notices go to $notices.
module MGQ_MpOverworldSync
  def self.map_free?; $free; end
  def self.notice(text, _icon = nil); ($notices ||= []) << text; end
end

$scene = Scene_Map.new
load_script "ui_online"
load_script "coop_choices"
FAKE, _FAKE_UI, _FAKE_EDIT = open_fake_ui { ["", 0] }

# Starts the menu scene the framework called last, which opens the window waiting for it.
#
# @return [Mod_Framework::UI::Window, nil] The window it opened, nil when it opened none.
def enter_menu
  $scene = $scenes.last.new
  $scene.start
  $scene.respond_to?(:menu_root) ? $scene.menu_root : nil
end

# Cancels a window as the player does with the game's cancel key, which C#'s tree takes.
#
# @param window [Mod_Framework::UI::Window] The window.
def cancel(window)
  window.receive("close")
end

# Finds the component of an open screen of the layer.
#
# @param id [Symbol] The screen's id.
# @return [Mod_Framework::UI::Component, nil] The component, nil while none is open.
def screen_part(id)
  top = Mod_Framework::UI::Engine::Layer.tops.find { |each| each.id == id.to_s && !each.closed }
  top && top.mount.component
end

# Hands out the texts of a window's labels, in their order.
#
# @param component [Mod_Framework::UI::Component] The window or a part of it.
# @return [Array<String>] The texts.
def label_texts(component)
  own = component.is_a?(Mod_Framework::UI::Label) ? [component.text.to_s] : []
  own + Array(component.children).map { |child| label_texts(child) }.flatten
end
