#----------------------------------------------------------------
#  bug_report_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Kept a member's levels per kind in one Hash, as the game does
#                            - Left the form to the in-game suite, since the UI layer draws it, and read the typing from the framework
#                            - Called the wheel's screenshot as the action wheel does once it is gone
#      Paulinchen  2026-11-05: Asked whether the DLL is a development build and the player's id through its topics
#                            - Dropped the stand-in of the World overview, which hid the untranslated game's name
#      Paulinchen  2026-11-01: Drew the form through the Mod Framework's window and answered the request from the DLL's topics
#                            - Covered a form open at F12
#                            - Dropped the stand-in of the title screen's commands, which no script hooks any more
#                            - Took the wheel's screenshot as the wheel is gone and waited while any mod's screen holds the game
#                            - Waited in the Mod Framework's menu scene of a mod's screen
#                            - Stopped loading the deleted ui_boxes.rbx
#      Paulinchen  2026-10-31: Read the hotkey's help from MGQ_MpHotkeys::HOTKEYS
#                            - Stood in for the Mod Framework's DLL and read the typing from $mgq_text_input
#                            - Expected the plainer texts the player reads
#      Paulinchen  2026-10-30: Stopped loading the deleted world_mods_parking.rbx
#                            - Expected the whole version the mod loader names
#                            - Dropped the default hotkey and the export signatures
#      Paulinchen  2026-10-23: Made the worlds on this PC through the stand-ins of the DLL's topics
#                            - Handed the screenshot to C# by the Bitmap's address, the walk to its pixels gone there
#                            - Typed through the stand-in text box
#                            - Told a report being sent here
#                            - Stood in for handing the log's lines over
#                            - Answered the rules the DLL owns through the bridge from the golden cases
#      Paulinchen  2026-10-22: Stood in for the update message
#      Paulinchen  2026-10-12: Checked when what the notification box says waits, shows or is dropped
#                            - Checked that the wheel scrolling the box being typed into draws it anew
#                            - Checked that a refused bug report hotkey is logged under the hotkeys
#                            - Checked the friendly words for a relay busy with other bug reports
#                            - Stood in for Ini.load
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Covers the in-game bug report, ui_bug_report.rbx: what it hands the DLL's request (the scene, the
# hotkey, the facts and details), the screenshot, the form on the Mod Framework's window, sending,
# closing, and what it plays, says and logs for the DLL. The request's own rules are
# BugReportRequestTests'; here the DLL answers from $answers and records each call in $asked.

require_relative "support"
require_relative "rules_support"

# Stands in for the game's base scene, counting return_scene in $returned.
class Scene_Base
  def start; end
  def update; end
  def terminate; end
  def return_scene; $returned += 1; end
end
# Stands in for the game's menu screens.
class Scene_MenuBase < Scene_Base; end
# Stands in for the game's main menu.
class Scene_Menu < Scene_MenuBase; end
# Stands in for the Mod Framework's menu scene of a mod's screen, such as the story's choices.
class Scene_ModScreen < Scene_MenuBase; include Mod_Framework::UI::Scenes::MenuRoot; end
# Stands in for the game's load screen.
class Scene_Load < Scene_Base; end
# Stands in for the game's title screen.
class Scene_Title < Scene_Base; end
# Stands in for the game's battle scene.
class Scene_Battle < Scene_Base; end
# Stands in for the game's map, which is changing once SceneManager holds another scene.
class Scene_Map < Scene_Base
  def update_scene; end
  def scene_changing?; SceneManager.scene != self; end
end
# Stands in for the game's data manager.
module DataManager; def self.save_system; end; end
# Stands in for the game's sounds, recording each one played in $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# Stands in for the game's scene manager, recording each scene called in $called.
module SceneManager
  class << self; attr_accessor :scene; end
  def self.call(klass); $called << klass; @scene = klass.new; end
end

# Stands in for the game's font, as the framework sets it to measure.
class Font
  attr_accessor :name, :size, :bold, :italic, :color, :outline, :out_color, :shadow
  def initialize(*); @size = 24; end
end
# A rectangle as the game's Rect holds it.
Rect = Struct.new(:x, :y, :width, :height) unless defined?(Rect)
# Stands in for the game's pictures, measuring each character at half the font's size.
class Bitmap
  attr_reader :width, :height, :font
  def initialize(width, height); @width = width; @height = height; @font = Font.new; end
  def text_size(text); Rect.new(0, 0, text.to_s.size * @font.size / 2, @font.size); end
  def dispose; @disposed = true; end
  def disposed?; @disposed == true; end
end

# The screen as Graphics.snap_to_bitmap gives it, keeping whether it was disposed.
class FakeBitmap
  attr_reader :width, :height
  def initialize(width, height); @width = width; @height = height; end
  def dispose; @disposed = true; end
  def disposed?; @disposed == true; end
end
# Stands in for the game's screenshot; each is kept in $bitmaps, and fails while $snap_fails holds.
module Graphics
  def self.snap_to_bitmap
    raise "no screen" if $snap_fails

    $bitmaps << FakeBitmap.new(4, 2)
    $bitmaps.last
  end
end

# Stands in for the mod's base script and its DLL.
module MGQ_Multiplayer
  DLL = "Multiplayer.dll"
  UPDATE_MESSAGE = "Update."
  # Gives the update message as it is.
  def self.update_message; UPDATE_MESSAGE; end
  def self.available?; true; end
  def self.outdated?; false; end
  def self.clean(text, _fallback = nil); text; end
  def self.path(name); "Patch\\Multiplayer\\#{name}"; end
  # Stands in for the mod's log, recording each line in $log.
  module Log; def self.write(message); $log << message; end; def self.hand_over; end; end
  # Stands in for the ini reader, finding nothing.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; end
  # Stands in for the player's identity and Player.ini, from $name and $player_ini.
  module Player
    def self.name; $name; end
    def self.share; true; end
    def self.setting(key); $player_ini[key]; end
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
  end
  # Stands in for the player's id, as the DLL tells it.
  module Player; def self.id; "0123abcd"; end; end
end

$sounds = []
$called = []
$bitmaps = []
$calls = []
$log = []
$player_ini = {}
$returned = 0
$name = "Player A"

load_script "core_hotkeys"
load_script "world_save_distribution"
load_script "ui_online"
load_script "world"
open_rules_bridge

# The registries and boxes the report takes part in, which keep what it hands them.
$ticks = []
$wheel = []
$notices = []
$chat = []
$map_free = true
$in_world = true
$shown = true
# Stands in for the overworld sync, keeping each tick in $ticks; the map is free while $map_free.
module MGQ_MpOverworldSync
  def self.on_tick(&block); $ticks << block; end
  def self.map_free?; $map_free; end
  def self.in_world?; $in_world; end
end
# Stands in for the action wheel, keeping each choice in $wheel.
module MGQ_MpActions
  # A choice of the action wheel.
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  def self.wheel_choice(order, &option); $wheel << [order, option]; end
end
# Stands in for the notification box, keeping each message in $notices; shown while $shown.
module MGQ_MpNotices
  def self.message(key, text, frames = 180); $notices << [key, text, frames]; end
  def self.shown?; $shown; end
end
# Stands in for the chat, keeping each system line in $chat.
module MGQ_MpChat; def self.system(text); $chat << text; end; end
# Stands in for the keyboard of the hotkeys: the bug report's hotkey goes down once while $hotkey.
def MGQ_MpHotkeys.pressed?(name)
  pressed = name == :bug_report && $hotkey
  $hotkey = false
  pressed ? true : false
end

load_script "ui_bug_report"

report = MGQ_MpBugReport

# A party member, by name and base level, whose level the game keeps per kind in one Hash.
Actor = Struct.new(:name, :base_level) { def level; { :base => base_level, :class => 1, :tribe => 1 }; end }
# The game as the report reads it: a player on map 154 of an open Raid World.
$game_map = Struct.new(:map_id, :display_name).new(154, "Test Village")
$game_player = Struct.new(:x, :y).new(3, 4)
$game_party = Struct.new(:members).new([Actor.new("Hero", 12), Actor.new("Fighter", 9)])
$game_system = Struct.new(:playtime_s).new("01:02:03")
$data_system = Struct.new(:variables).new([nil, "Overall Events Progress"])
$patch_ver = "v3.06.00"
MGQ_MpWorld.instance_variable_set(:@world, local_world("folder", "name" => "Test World", "world" => "dir0123", "type" => "raid"))
$dev_build = false
# A world in the directory's list.
Listed = Struct.new(:id, :name, :hidden)
# The world list as the directory last sent it, the open world public in it.
$listing = ["ready", "", [Listed.new("dir0123", "Test World", false)]]
# Stands in for the world directory, listing $listing.
module MGQ_MpWorld::Directory; def self.list; $listing; end; end

# The registrations.
check("the report follows every frame and adds its choice after the wheel's others", [$ticks.size, $wheel.map(&:first)], [1, [60]])

# The facts and details.
SceneManager.scene = Scene_Map.new
check("the public facts: the game, the world and where, the DLL adding the mod's version",
      report.facts(SceneManager.scene), [["Game", "v3.06.00, translated"], ["World", "Raid, Test World"], ["Where", "Scene_Map, map 154"]])
$listing[2][0].hidden = true
check("a hidden world keeps its name out of the public facts", report.facts(SceneManager.scene)[1], ["World", "Raid, a hidden world"])
$listing = ["loading", "", []]
check("as does a world while the list is not there", report.facts(SceneManager.scene)[1], ["World", "Raid, a hidden world"])
$listing = ["ready", "", [Listed.new("dir0123", "Test World", false)]]
$dev_build = true
MGQ_MpWorld.instance_variable_set(:@dev_build, nil)
check("a development build says so", report.facts(Scene_Battle.new).last(2), [["Where", "Scene_Battle, map 154"], ["Development build", "yes"]])
$dev_build = false
MGQ_MpWorld.instance_variable_set(:@dev_build, nil)
check("the private details: the player with the id everyone sees, the world, the map, position, party and time",
      report.details(SceneManager.scene),
      [["Player", "Player A (0123abcd)"], ["World", "Test World (dir0123)"], ["Map", "Test Village (154)"], ["Position", "3, 4"],
       ["Party", "Hero Lv 12, Fighter Lv 9"], ["Time played", "01:02:03"]])
$data_system.variables = [nil, "総合イベント進行度"]
$patch_ver = nil
check("the untranslated game, and a game without the loader's version", report.game_text, "unknown version, untranslated")
$data_system.variables = []
check("a game whose progress variable has neither name", report.game_text, "unknown version, translation unknown")
$patch_ver = "v3.06.00.ru.0.2.1"
check("a translation's own loader, with the version it names", report.game_text, "v3.06.00.ru.0.2.1, translation unknown")
$data_system.variables = [nil, "Overall Events Progress"]
$patch_ver = "v3.06.00"
world = MGQ_MpWorld.world
MGQ_MpWorld.instance_variable_set(:@world, nil)
check("outside a world", [report.world_type, report.world_text], ["none", "none"])
MGQ_MpWorld.instance_variable_set(:@world, world)
$game_map.display_name = ""
check("a map without a name is named by its id", report.map_text, "154")
$game_map.display_name = "Test Village"
broken = Object.new
def broken.x; raise "gone"; end
$game_player, kept_player = broken, $game_player
check("a detail that cannot be read is unknown, and the others stay", report.details(SceneManager.scene)[3], ["Position", "unknown"])
$game_player = kept_player

# The DLL's side: the request's topics answer from $answers and record each call in $asked; the
# screenshot's topic keeps each Bitmap unless $answers says false.
fake, _ui, _edit = open_fake_ui { ["", 0] }
fake.answer("ui.tree.layout") { |_changes| {} }
$answers = {}
$asked = []
(%w[tick snapped on_map wheel_refusal wheel wheel_gone take_opening send closed].map { |name| "report.#{name}" } + [report::Screenshot::TOPIC]).each do |topic|
  fake.answer(topic) { |request| $asked << [topic, request]; $answers.key?(topic) ? $answers[topic] : (topic == report::Screenshot::TOPIC || nil) }
end
tree = Mod_Framework::UI::Tree
# Whether any mod types, as the framework tells it, from $typing.
Mod_Framework::UI.define_singleton_method(:typing?) { $typing == true }

# Runs a frame: the hooks after Graphics.update, the map's update_scene when the map is the scene,
# then the frame's end, whose drain hands the DLL's events over.
def frame
  $ticks.each { |tick| tick.call($in_world) }
  SceneManager.scene.update_scene if SceneManager.scene.is_a?(Scene_Map)
  ui_frame
end

# Forgets every call and answer and what was played and said, so a check reads only what follows.
def reset
  [$called, $asked, $notices, $chat, $sounds, $log, $calls].each(&:clear)
  $answers.clear
end

# Tells what the DLL was asked under a topic.
#
# @param topic [String] The topic.
# @return [Array] Each request.
def asked(topic)
  $asked.select { |name, _| name == topic }.map { |_, request| request }
end

# What a frame hands the DLL.
SceneManager.scene = Scene_Map.new
reset
frame
check("each frame tells the DLL the scene, whether the map is ready, the box shows and the player types, without facts",
      [asked("report.tick").last["scene"], asked("report.tick").last["hotkey"], asked("report.tick").last.key?("facts")],
      [{ "name" => "Scene_Map", "place" => "map", "in_world" => true, "map_ready" => true, "shown" => true, "typing" => false }, false, false])
places = [Scene_Battle, Scene_Menu, Scene_ModScreen, Scene_Title, Scene_Load].map do |klass|
  SceneManager.scene = klass.new
  frame
  asked("report.tick").last["scene"]["place"]
end
check("a battle, a menu, a mod's menu scene such as the story's choices, the title and any other scene each have their place", places,
      ["battle", "menu", "waiting_menu", "title", "other"])
ui = Mod_Framework::UI
known = ui.respond_to?(:menu_screen?) ? ui.method(:menu_screen?) : nil
ui.singleton_class.send(:remove_method, :menu_screen?) if known
check("an older Mod Framework without UI.menu_screen? still waits in a mod's menu scene and opens over the game's menu",
      [report.place_of(Scene_ModScreen.new), report.place_of(Scene_Menu.new)], ["waiting_menu", "menu"])
ui.define_singleton_method(:menu_screen?, known) if known
SceneManager.scene = Scene_Map.new
$map_free = false
$typing = true
frame
check("a busy map is not ready, and typing is told", asked("report.tick").last["scene"].values_at("map_ready", "typing"), [false, true])
$map_free = true
$typing = false
capture = Mod_Framework::UI::Capture
held = capture.method(:on?)
capture.define_singleton_method(:on?) { true }
frame
check("nor is a free map while a screen of a mod holds the game", asked("report.tick").last["scene"]["map_ready"], false)
capture.define_singleton_method(:on?, held)
$hotkey = true
frame
by_hotkey = asked("report.tick").last
check("the hotkey goes with where the player is and the report's facts and details",
      [by_hotkey["hotkey"], by_hotkey["where"], by_hotkey["facts"].last, by_hotkey["details"].first],
      [true, "Scene_Map, map 154", ["Where", "Scene_Map, map 154"], ["Player", "Player A (0123abcd)"]])
check("nothing is snapped while the DLL does not say so", [$bitmaps, asked("report.snapped")], [[], []])

# The screenshot the DLL asks for, then the form at once in a menu.
reset
SceneManager.scene = Scene_Menu.new
$answers["report.tick"] = true
$answers["report.snapped"] = true
$answers["report.take_opening"] = true
frame
check("the screenshot hands C# the screen's bitmap by its address, with its size, and disposes it",
      [asked(report::Screenshot::TOPIC).first, $bitmaps.last.disposed?], [[$bitmaps.last.object_id * 2, 4, 2], true])
check("then tells the DLL it was kept, in the menu", asked("report.snapped").first,
      { "kept" => true, "scene" => asked("report.tick").last["scene"] })
check("and the form opens", report.form.nil?, false)
report.form.close
check("closing it tells the DLL why", [asked("report.closed"), report.form], [["the script closed it"], nil])
reset

# A screenshot that fails or the DLL did not keep.
$snap_fails = true
$answers["report.tick"] = true
frame
check("a screenshot that fails is told as not kept", asked("report.snapped").last["kept"], false)
$snap_fails = false
$answers[report::Screenshot::TOPIC] = false
frame
check("as is one the DLL did not keep, its bitmap disposed", [asked("report.snapped").last["kept"], $bitmaps.last.disposed?], [false, true])
reset

SceneManager.scene = Scene_Map.new
$answers["report.on_map"] = true
frame
check("no form opens when the DLL hands none over", [report.form, $log.last], [nil, "bug report: no report waits for a form"])
reset

# The action wheel's choice.
$bitmaps.clear
$answers["report.wheel_refusal"] = "The last bug report is still being sent."
option = $wheel.first[1].call
check("the wheel's choice is refused as the DLL says", [option.text, option.run, option.refusal], ["Report a Bug", nil, "The last bug report is still being sent."])
$answers.delete("report.wheel_refusal")
option = $wheel.first[1].call
option.run.call
taken = asked("report.wheel").first
check("taken, it hands the DLL the scene, where and the facts", [taken["scene"]["place"], taken["where"], taken["facts"].first],
      ["map", "Scene_Map, map 154", ["Game", "v3.06.00, translated"]])
check("the screenshot waits while the wheel still shows", [$bitmaps.size, asked("report.wheel_gone")], [0, []])
$answers["report.wheel_gone"] = true
report.wheel_gone
check("once the wheel is gone, it is taken when the DLL says so", [$bitmaps.size, asked("report.snapped").size], [1, 1])
$answers["report.wheel_gone"] = false
report.wheel_gone
check("a wheel gone later takes none", [$bitmaps.size, asked("report.snapped").size], [1, 1])
$bitmaps.clear
reset

# What the DLL tells.
fake.post("report.sound", "buzzer")
fake.post("report.notice", "text" => "Sending the bug report . . .", "frames" => 600)
fake.post("report.notice", "text" => "A bug report waits to open already.", "frames" => nil)
fake.post("report.chat_line", "The bug report opens after the battle.")
fake.post("report.hotkey_refused", "the game shows the title or game over screen")
ui_frame
check("the DLL's sounds play, its messages go to the box, its lines to the battle's chat",
      [$sounds, $notices, $chat],
      [["buzzer"], [[:bug_report, "Sending the bug report . . .", 600], [:bug_report, "A bug report waits to open already.", 180]],
       ["The bug report opens after the battle."]])
check("and a refused hotkey is logged under the hotkeys", $log.grep(/ignored/),
      ["keys: hotkey F3 (Report a Bug) ignored: the game shows the title or game over screen"])
reset

# The texts.
check("the hotkey's help names it a hotkey", MGQ_MpHotkeys::HOTKEYS[:bug_report].help.start_with?("The hotkey"), true)
