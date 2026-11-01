#----------------------------------------------------------------
#  ui_online_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Left the world status to register as its box of the Mod Framework opens
#      Paulinchen  2026-10-31: Created
#
#----------------------------------------------------------------

# Covers MGQ Online's interface on the Mod Framework as the map's scripts load: one set of look and
# place rows in Options > Mods, the framework's, the boxes of the map registered under their old
# ids, and Interface Positions putting a moved box back.

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
Mod_Framework::UI::Theme.start_settings
Mod_Framework::UI::Layout.add_option
keys = NWConst::Config::MOD_CONTENTS.map { |row| row[:key].to_s }
check("Options > Mods holds none of MGQ Online's own look or place rows", keys.grep(/\Amp_ui_/), [])
check("and each of the framework's once", %w[mf_ui_positions mf_ui_preset mf_ui_game_windows].map { |key| keys.count(key) }, [1, 1, 1])

# The map's boxes drawn on their own, under the ids their places were kept by before; the boxes of
# the framework's components register as they open.
check("the map's boxes register with the framework's layout under their old ids",
      [:chat, :battle_chat, :menu_chat].map { |id| $layout_registrations.key?(id) }, [true] * 3)

# Interface Positions puts a moved box back where it starts.
layout = Mod_Framework::UI::Layout
default = Rect.new(8, 100, 400, 200)
Mod_Framework::Settings.store("ui_chat", "100,40,420,150")
layout.forget(:chat)
moved = [layout.rect(:chat, default).to_a, layout.moved?(:chat)]
layout.reset_all("picked Default in a test")
check("Interface Positions' Default puts a moved chat back where it starts, forgetting its place",
      [moved, layout.rect(:chat, default).to_a, layout.moved?(:chat), Mod_Framework::Settings.setting("ui_chat")],
      [[[100, 40, 420, 150], true], [8, 100, 400, 200], false, nil])
