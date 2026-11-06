#----------------------------------------------------------------
#  ui_online_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that a HUD part the UI layer refused is asked again a while later and in a new scene
#                            - Reached the Mod Framework's engine under its own name
#                            - Left the chat's places to the windows of the UI layer, which keep them as they open
#      Paulinchen  2026-11-01: Left the world status to register as its box of the Mod Framework opens
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers MGQ Online's interface on the Mod Framework as the map's scripts load: one set of look and
# place rows in Options > Mods, the framework's, and its HUD parts asked again after a refusal.

# Options > Mods with its Return row alone, which every row goes before.
module NWConst
  module Config
    MOD_CONTENTS = [{ :key => :return }]
    DATA = {}
    DATA_TEXT = {}
    DEFAULT = {}
  end
end

require_relative "world_support"

# The game's data manager, whose new objects and loaded saves the framework puts the window color
# into.
module DataManager
  # Makes the game's objects.
  def self.create_game_objects; end
  # Loads a save.
  def self.load_game_without_rescue(_index); true; end
end

# The look's and the places' rows, as the framework adds them once the game runs with its DLL.
Mod_Framework::UI::Engine::Theme.start_settings
Mod_Framework::UI::Engine::Layout.add_option
keys = NWConst::Config::MOD_CONTENTS.map { |row| row[:key].to_s }
check("Options > Mods holds none of MGQ Online's own look or place rows", keys.grep(/\Amp_ui_/), [])
check("and each of the framework's once", %w[mf_ui_positions mf_ui_preset mf_ui_game_windows].map { |key| keys.count(key) }, [1, 1, 1])

# A HUD part the UI layer refuses to show is asked again a while later, and at once in a new scene,
# the refusal logged once.
refusing = true
shows = 0
part = Object.new
def part.shown?; true; end
Mod_Framework::UI.define_singleton_method(:show) { |_klass, _params = {}| shows += 1; refusing ? nil : part }
lines = logged_lines { MGQ_MpShown::RETRY_FRAMES.times { MGQ_MpShown.keep(:status, Object) } }
check("a refused part waits before it is asked again, the refusal logged once", [shows, lines.size], [1, 1])
lines = logged_lines { MGQ_MpShown.keep(:status, Object) }
check("a while later it is asked again, without a second line", [shows, lines], [2, []])
SceneManager.scene = Object.new
refusing = false
check("a new scene asks at once, and the part shown is kept", [MGQ_MpShown.keep(:status, Object), MGQ_MpShown.keep(:status, Object), shows], [part, part, 3])

