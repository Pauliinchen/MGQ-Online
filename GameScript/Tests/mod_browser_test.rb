#----------------------------------------------------------------
#  mod_browser_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-24: Checked the screenshots, the descriptions, the page's buttons and the input without cards
#                            - Created
#
#----------------------------------------------------------------

# Covers the Mods screen, ui_mod_browser.rbx: the list as the DLL writes it, the title command
# below Multiplayer with the updates it counts, the buttons a mod's page offers for each kind of
# mod, and the changes it refuses while mods are parked.

require_relative "support"

# The game's scene base, which does nothing.
class Scene_Base; def return_scene; end; def update; end; end
# The game's base of menu scenes.
class Scene_MenuBase < Scene_Base; end
# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The game's window with a cursor.
class Window_Selectable < Window_Base; end
# The game's command window.
class Window_Command < Window_Selectable; end
# The game's command window of side by side buttons.
class Window_HorzCommand < Window_Command; end
# The game's color.
class Color; def initialize(*); end; end
# The game's title screen, which does nothing.
class Scene_Title; def start; end; def create_command_window; end; def update; end; def scene_changing?; false; end; end
# The title screen's commands, which list nothing.
class Window_TitleCommand; def make_command_list; end; end
# The game's system sounds: each one played is added to $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# The interface's shared parts the windows include.
module MGQ_MpUi; module Theme; module Skinned; end; end; module ScrollingWindow; end; end
# The parked mods, parked while $parked is.
module MGQ_MpModParking; def self.parked?; $parked; end; end

# The mod's base script with a link to the DLL that records each call in $calls and reads the list
# from $dll_list.
module MGQ_Multiplayer
  # The DLL is always there.
  def self.available?; true; end
  # The mod's log, kept in $log.
  module Log; def self.write(message); ($log ||= []) << message; end; end
  # The link to the DLL.
  module Link
    # A DLL function: a call is checked against its signature and recorded; it answers $answer.
    Function = Struct.new(:name) do
      # Calls the function.
      #
      # @param args [Array] The call's arguments.
      # @return [Integer] $answer.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        $answer
      end
    end
    # A DLL function.
    def self.function(name); Function.new(name); end
    # The list the DLL holds.
    def self.read(_name, _size); $dll_list.to_s; end
    # Reads a DLL answer: its name=value lines up to a blank line, and the rest as :payload.
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end

load_script "ui_mod_browser"

$calls = []
$sounds = []
$answer = 1

# Writes a list as the DLL does.
#
# @param headers [Hash] The headers.
# @param lines [Array<Array<String>>] The payload's lines, each as its fields.
# @return [String] The text.
def dll_list(headers, lines)
  "#{headers.map { |key, value| "#{key}=#{value}" }.join("\n")}\n\n#{lines.map { |fields| fields.join("\t") }.join("\n")}"
end

PARTY_SHEET = ["mod", "site:party-sheet", "Party Sheet", "Paulinchen", "update", "1.5.1", "1.5.2", "site", "https://mgqonline.org/mods/party-sheet", "1", "144964", "Uploads the party.", 'Patch\Multiplayer\Cache\Mods\0123456789abcdef.png', "1"]
LEVEL_CAP = ["mod", "site:level-cap", "Level Cap", "Paulinchen", "changed", "", "1.5.2", "site", "https://mgqonline.org/mods/level-cap", "1", "71032", "Caps levels.", "", ""]
MAP_DISPLAY = ["mod", "relay:mapdisplay", "Map Display", "", "current", "1.5.2", "1.5.2", "github", "", "1", "0", "", ""]

# The list: parsed with its headers, each mod's fields, its changelog and its description.
$dll_list = dll_list({ "state" => "ready", "updates" => 1, "action" => "done", "done" => "Installed Map Display 1.5.2.", "restart" => 1 },
                     [PARTY_SHEET, ["note", "site:party-sheet", "Fixed the faces."], ["note", "site:party-sheet", "Added uploads."], ["desc", "site:party-sheet", "Shows the party."], LEVEL_CAP, MAP_DISPLAY])
list = MGQ_MpModBrowser.list
check("the list's state", list.state, "ready")
check("the updates counted", list.updates, 1)
check("a restart is due", list.restart, true)
check("what the last change did", list.done, "Installed Map Display 1.5.2.")
check("the mods in the DLL's order", list.mods.map(&:name), ["Party Sheet", "Level Cap", "Map Display"])
check("a mod's versions and size", [list.mods[0].installed, list.mods[0].latest, list.mods[0].bytes], ["1.5.1", "1.5.2", 144964])
check("the changelog joins its mod", list.mods[0].notes, ["Fixed the faces.", "Added uploads."])
check("a mod without changelog has none", list.mods[2].notes, [])
check("the description joins its mod", list.mods[0].description, ["Shows the party."])
check("the screenshot and whether it is a spoiler", [list.mods[0].thumbnail, list.mods[0].spoiler], ['Patch\Multiplayer\Cache\Mods\0123456789abcdef.png', true])
check("a mod without screenshot has none", [list.mods[1].thumbnail, list.mods[1].spoiler], ["", false])

# The title command: below Multiplayer, counting the updates.
commands = Window_TitleCommand.new
commands.instance_variable_set(:@list, [{ :symbol => :new_game }, { :symbol => :continue }, { :symbol => :mgq_mp_world }, { :symbol => :shutdown }])
MGQ_MpModBrowser.add_title_command(commands)
entries = commands.instance_variable_get(:@list)
check("Mods sits below Multiplayer", entries.map { |entry| entry[:symbol] }, [:new_game, :continue, :mgq_mp_world, :mgq_mp_mods, :shutdown])
check("Mods counts the updates", entries[3][:name], "Mods (1)")

# Without Multiplayer's command the Mods command sits below Continue.
commands.instance_variable_set(:@list, [{ :symbol => :new_game }, { :symbol => :continue }, { :symbol => :shutdown }])
MGQ_MpModBrowser.add_title_command(commands)
check("Mods sits below Continue", commands.instance_variable_get(:@list).map { |entry| entry[:symbol] }, [:new_game, :continue, :mgq_mp_mods, :shutdown])

# The title screen names the count anew once the DLL tells another one.
class Window_TitleCommand; attr_reader :refreshed; def refresh; @refreshed = true; end; def disposed?; false; end; end
title = Scene_Title.new
shown = Window_TitleCommand.new
shown.instance_variable_set(:@list, [{ :symbol => :mgq_mp_mods, :name => "Mods (1)" }])
title.instance_variable_set(:@command_window, shown)
MGQ_MpModBrowser.on_title_start
MGQ_MpModBrowser.on_title_update(title)
check("an unchanged count leaves the command", shown.refreshed, nil)
$dll_list = dll_list({ "state" => "ready", "updates" => 0 }, [MAP_DISPLAY])
MGQ_MpModBrowser::LOOK_FRAMES.times { MGQ_MpModBrowser.on_title_update(title) }
check("another count redraws the command", shown.refreshed, true)

# A change goes to the DLL as one call of lines, each its kind and the mod's id.
$calls.clear
MGQ_MpModBrowser.apply([[:install, list.mods[0]], [:remove, list.mods[2]]])
check("the change sent", $calls.last, ["mp_mod_browser_apply", ["install\tsite:party-sheet\nremove\trelay:mapdisplay\0"]])

# The buttons of a mod's page, by its status.
buttons = lambda do |mod|
  window = Window_MpModPageCommands.allocate
  added = []
  window.define_singleton_method(:add_command) { |name, symbol, enabled = true| added << [name, symbol, enabled] }
  window.instance_variable_set(:@mod, mod)
  window.make_command_list
  added
end
check("an update offers the update, removal, the page and Back", buttons.call(list.mods[0]),
      [["Update to 1.5.2", :install, true], ["Remove", :remove, true], ["Open page", :open_site, true], ["Back", :back, true]])
check("a changed copy is replaced, never removed", buttons.call(list.mods[1]).map { |button| button[0, 3] }[0, 2],
      [["Replace with 1.5.2", :replace, true], ["Remove", :remove, false]])
check("an installed mod without a page offers neither install nor its page", buttons.call(list.mods[2]),
      [["Installed", :install, false], ["Remove", :remove, true], ["Open page", :open_site, false], ["Back", :back, true]])

# No change starts while mods are parked for a world.
# Stands in for a window that takes and gives back the input.
FakeWindow = Struct.new(:active, :item_max) do
  def activate; self.active = true; end
  def deactivate; self.active = false; end
end
# Stands in for the bar, keeping what it shows.
FakeBar = Struct.new(:status, :message) { def show(status, message); self.status = status; self.message = message; end }
scene = Scene_MpMods.new
bar = FakeBar.new
grid = FakeWindow.new(false, 3)
scene.instance_variable_set(:@bar, bar)
scene.instance_variable_set(:@grid, grid)
scene.instance_variable_set(:@bar_commands, FakeWindow.new(false, 2))
scene.instance_variable_set(:@page_commands, FakeWindow.new(false, 4))
scene.instance_variable_set(:@list, list)
$parked = true
$calls.clear
scene.change([[:install, list.mods[0]]])
check("nothing goes to the DLL while mods are parked", $calls, [])
check("the bar says why", bar.message, Scene_MpMods::PARKED_TEXT)
check("the cards take the input back", grid.active, true)
$parked = false

# Without cards, as offline or before the first list, the bar holds the input so Refresh is in
# reach, and the cards take it once they arrive; Enter opens no card that is not there.
bar_commands = FakeWindow.new(false, 2)
grid = FakeWindow.new(true, 0)
scene.instance_variable_set(:@grid, grid)
scene.instance_variable_set(:@bar_commands, bar_commands)
scene.follow_cards
check("an empty grid hands the input to the bar", [grid.active, bar_commands.active], [false, true])
grid.item_max = 3
scene.follow_cards
check("the first cards take the input back", [grid.active, bar_commands.active], [true, false])
empty = Window_MpModGrid.allocate
empty.instance_variable_set(:@mods, [])
empty.define_singleton_method(:index) { -1 }
check("Enter on an empty grid opens nothing", empty.current_item_enabled?, false)
