#----------------------------------------------------------------
#  bug_report_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-12: Checked the friendly words for a relay busy with other bug reports
#      Paulinchen  2026-10-11: Created
#
#----------------------------------------------------------------

# Covers the in-game bug report, ui_bug_report.rbx: the hotkey and the action wheel's choice, the
# screenshot handed to the DLL, the form opening at once on the map and in menus and after a
# battle, the refusals, the public facts and private details, the form and its typing, sending,
# the outcome in the notification box, and the screenshot dropped when the form closes unsent. The
# DLL and Windows stand in, the DLL answering from $results and $state, the game's memory from
# $memory.

require_relative "support"

# Stand-ins for the game.
class Scene_Base
  def update; end
  def terminate; end
  def return_scene; $returned += 1; end
end
class Scene_MenuBase < Scene_Base; end
class Scene_Menu < Scene_MenuBase; end
class Scene_MpStoryChoices < Scene_MenuBase; end
class Scene_Load < Scene_Base; end
class Scene_Title < Scene_Base; end
class Scene_Battle < Scene_Base; end
class Scene_Map < Scene_Base
  def update_scene; end
  def scene_changing?; SceneManager.scene != self; end
end
class Window_Base; def initialize(*); end; end
class Window_Selectable < Window_Base; end
class Window_Command < Window_Selectable; end
class Window_NameEdit < Window_Base; end
class Window_NameInput < Window_Selectable; end
class Color; def initialize(*); end; end
class Sprite; def initialize(*); end; end
Rect = Struct.new(:x, :y, :width, :height)
class Window_TitleCommand; def make_command_list; end; end
module DataManager; def self.save_system; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
module Input; def self.press?(button); $held.include?(button); end; end
module SceneManager
  class << self; attr_accessor :scene; end
  def self.call(klass); $called << klass; @scene = klass.allocate; end
end

# The screen as Graphics.snap_to_bitmap gives it, which keeps whether it was disposed.
class FakeBitmap
  attr_reader :width, :height
  def initialize(width, height); @width = width; @height = height; end
  def dispose; @disposed = true; end
  def disposed?; @disposed == true; end
end
module Graphics
  def self.width; 640; end
  def self.height; 480; end
  def self.snap_to_bitmap
    raise "no screen" if $snap_fails

    $bitmaps << FakeBitmap.new(4, 2)
    lay_out($bitmaps.last)
    $bitmaps.last
  end
end

# The game's memory as RtlMoveMemory reads it: bytes by their address.
$memory = {}

# Where the pixels of the last bitmap laid out lie.
PIXELS_AT = 0x3000

# Lays a bitmap's pointers and pixels into the memory, as RGSS3 keeps them.
#
# @param bitmap [FakeBitmap] The bitmap.
# @return [String] Its pixels.
def lay_out(bitmap)
  data, info = 0x1000, 0x2000
  $memory[bitmap.object_id * 2 + 16] = [data].pack("L")
  $memory[data + 8] = [info].pack("L")
  $memory[info + 16] = [PIXELS_AT].pack("L")
  $memory[PIXELS_AT] = (0...bitmap.width * bitmap.height * 4).map { |byte| (byte % 256).chr }.join
end

# A Windows function, which answers as Windows would from $memory.
WindowsFunction = Struct.new(:name, :arguments) do
  def call(*args)
    $windows << name
    case name
    when "RtlMoveMemory"
      buffer, address, length = args
      bytes = $memory[address].to_s
      buffer[0, length] = bytes[0, length].ljust(length, "\0")
      0
    end
  end
end

# Stand-ins for the mod's base script and its DLL.
module MGQ_Multiplayer
  DLL = "Multiplayer.dll"
  UPDATE_MESSAGE = "Update."
  def self.available?; true; end
  def self.outdated?; false; end
  def self.clean(text, _fallback = nil); text; end
  def self.path(name); "Patch\\Multiplayer\\#{name}"; end
  module Log; def self.write(message); $log << message; end; end
  module Ini; def self.read(_path); {}; end; end
  module Player
    def self.name; $name; end
    def self.share; $share; end
    def self.setting(key); $player_ini[key]; end
    def self.store(key, value); $player_ini[key] = value.to_s; true; end
  end
  module Background; def self.running?; $running; end; def self.in_front?; true; end; end
  module Key
    def self.watch(*_codes); end
    def self.pressed?(code); $pressed == code ? (($pressed = nil) || true) : false; end
    def self.triggered?(code); code == 0x60 && $numpad; end
  end
  module Capture
    def self.start(_owner); end
    def self.stop(_owner); end
    def self.trigger?(button); $buttons.delete(button) ? true : false; end
    def self.press?(_button); false; end
    def self.repeat?(_button); false; end
    def self.on?; false; end
  end
  module Mouse; def self.clicked?; false; end; end
  module Windows; def self.api(_library, name, arguments, _result); WindowsFunction.new(name, arguments); end; end
  module Link
    Function = Struct.new(:name, :signature) do
      def call(*args); check_dll_call(name, args); $calls << [name, args]; $results.fetch(name, 1); end
    end
    def self.function(name); Function.new(name, dll_signature(name)); end
    def self.read(name, _size); name == "mp_report_state" ? $state.dup : ""; end
    def self.player_id; "0123abcd"; end
    def self.typing(on); $typing_on = on; end
    def self.take_typed; text = $typed; $typed = ""; [text, text.size]; end
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end

$sounds = []
$held = []
$buttons = []
$called = []
$bitmaps = []
$windows = []
$calls = []
$results = {}
$state = ""
$log = []
$player_ini = {}
$returned = 0
$name = "Player A"
$share = true
$running = true
$typed = ""

load_script "core_hotkeys"
load_script "world_save_distribution"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_mods"
load_script "world_mods_parking"
load_script "world_text"
load_script "world_screen"

# The registries and boxes the report takes part in, which keep what it hands them.
$ticks = []
$wheel = []
$notices = []
$chat = []
$map_free = true
$covered = false
$in_world = true
$shown = true
module MGQ_MpOverworldSync
  def self.on_tick(&block); $ticks << block; end
  def self.map_free?; $map_free; end
  def self.in_world?; $in_world; end
end
module MGQ_MpActions
  Option = Struct.new(:text, :run, :refusal, :icon, :leaves)
  def self.wheel_choice(order, &option); $wheel << [order, option]; end
  def self.covered?; $covered; end
end
module MGQ_MpNotices
  def self.message(key, text, frames = 180); $notices << [key, text, frames]; end
  def self.shown?; $shown; end
end
module MGQ_MpChat; def self.system(text); $chat << text; end; end
module MGQ_MpWorldOverview; PROGRESS = ["Overall Events Progress", "総合イベント進行度"]; end

load_script "ui_bug_report"

report = MGQ_MpBugReport

# The game as the report reads it: a player on map 154 of an open Raid World.
Actor = Struct.new(:name, :level)
$game_map = Struct.new(:map_id, :display_name).new(154, "Test Village")
$game_player = Struct.new(:x, :y).new(3, 4)
$game_party = Struct.new(:members).new([Actor.new("Hero", 12), Actor.new("Fighter", 9)])
$game_system = Struct.new(:playtime_s).new("01:02:03")
$data_system = Struct.new(:variables).new([nil, "Overall Events Progress"])
$patch_ver = "v3.06.00"
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("folder", "name" => "Test World", "world" => "dir0123", "type" => "raid"))
$results["mp_dev_build"] = 0
# The world list as the directory last sent it, the open world public in it.
Listed = Struct.new(:id, :name, :hidden)
$listing = ["ready", "", [Listed.new("dir0123", "Test World", false)]]
module MGQ_MpWorld::Directory; def self.list; $listing; end; end

# Runs a frame: the hooks after Graphics.update, then the map's update_scene when the map is the
# scene.
def frame
  $ticks.each { |tick| tick.call($in_world) }
  SceneManager.scene.update_scene if SceneManager.scene.is_a?(Scene_Map)
end

# Opens nothing more and forgets every call, so a check reads only what follows.
def reset
  MGQ_MpBugReport.take_opening
  [$called, $calls, $notices, $chat, $sounds, $windows, $log].each(&:clear)
end

# The registrations.
check("the report follows every frame and adds its choice after the wheel's others", [$ticks.size, $wheel.map(&:first)], [1, [60]])
check("its hotkey is F3 unless bound, named in Mod Config", [MGQ_MpHotkeys.code(:bug_report), MGQ_MpHotkeys::BINDINGS[:bug_report].name], [0x72, "Report a Bug"])
check("the exports have the contract's signatures",
      %w[mp_report_snap mp_report_drop_snap mp_report_send mp_report_state].map { |name| dll_signature(name) }, %w[pll v ppppl pl])

# The facts and details.
SceneManager.scene = Scene_Map.new
check("the public facts: the game, the world and where, the DLL adding the mod's version",
      report.facts(SceneManager.scene), [["Game", "3.06, translated"], ["World", "Raid, Test World"], ["Where", "Scene_Map, map 154"]])
$listing[2][0].hidden = true
check("a hidden world keeps its name out of the public facts", report.facts(SceneManager.scene)[1], ["World", "Raid, a hidden world"])
$listing = ["loading", "", []]
check("as does a world while the list is not there", report.facts(SceneManager.scene)[1], ["World", "Raid, a hidden world"])
$listing = ["ready", "", [Listed.new("dir0123", "Test World", false)]]
$results["mp_dev_build"] = 1
MGQ_MpWorld.instance_variable_set(:@dev_build, nil)
check("a development build says so", report.facts(Scene_Battle.new).last(2), [["Where", "Scene_Battle, map 154"], ["Development build", "yes"]])
$results["mp_dev_build"] = 0
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
check("facts are lines of a label and a value, on one line, cut to the relay's lengths",
      report.lines([["A" * 40, "x\ty\nz"], ["Long", "v" * 200]], report::MAX_VALUE_CHARS), "#{'A' * 32}\tx y z\nLong\t#{'v' * 120}")

# The hotkey on the map: the screenshot at the press, then the form from the map's update.
reset
$pressed = 0x72
frame
snap = $calls.find { |name, _| name == "mp_report_snap" }
check("the hotkey hands the screen's pixels to the DLL, read through the bitmap's pointers, with its size",
      snap && [snap[1][0] == $memory[PIXELS_AT], snap[1][0].bytesize, snap[1][1], snap[1][2]], [true, 32, 4, 2])
check("and disposes the screen's bitmap", $bitmaps.last.disposed?, true)
check("and the form opened on the free map", $called, [Scene_MpBugReport])
opening = report.take_opening
check("with the screenshot, the facts and the details", [opening[:snapped], opening[:facts].last, opening[:details].first],
      [true, ["Where", "Scene_Map, map 154"], ["Player", "Player A (0123abcd)"]])

# The pixels, now that the memory holds them for the next bitmap.
reset
SceneManager.scene = Scene_Map.new
bitmap = FakeBitmap.new(4, 2)
pixels = lay_out(bitmap)
check("the pixels are copied whole from where the pointers lead", report::Screenshot.pixels_of(bitmap), pixels)
check("an address past 2**31 goes to Win32API as a signed long", [report::Screenshot.signed(0x80000000), report::Screenshot.signed(5)], [-0x80000000, 5])
$memory.delete(bitmap.object_id * 2 + 16)
check("an empty pointer fails instead of reading from nowhere", (report::Screenshot.pixels_of(bitmap) rescue :failed), :failed)

# In a menu the form opens at once.
reset
SceneManager.scene = Scene_Menu.new
$pressed = 0x72
frame
check("in a menu the form opens at once", [$called, $sounds], [[Scene_MpBugReport], ["ok"]])
$pressed = 0x72
frame
check("pressing again while the form opens does nothing", [$called.size, report.take_opening.nil?], [1, false])
reset

# In a battle the screenshot is taken at the press and the form opens back on the map.
SceneManager.scene = Scene_Battle.new
$pressed = 0x72
frame
check("in a battle the screenshot is taken at the press, the chat says the form opens after it",
      [$calls.map(&:first), $chat, $called], [["mp_report_snap"], [report::BATTLE_TEXT], []])
$pressed = 0x72
frame
check("a second press while one waits is refused in the chat", $chat.last, report::WAITING_REFUSAL)
SceneManager.scene = Scene_Map.new
$map_free = false
frame
check("the form waits while the map is busy", $called, [])
$map_free = true
$covered = true
frame
check("and while a screen of the mod lies over it", $called, [])
$covered = false
frame
check("then opens on the free map", $called, [Scene_MpBugReport])
reset

# Outside a world, a battle's report is told in the notification box, where the chat is closed.
$in_world = false
SceneManager.scene = Scene_Battle.new
$pressed = 0x72
frame
check("outside a world the box is told instead", [$chat, $notices.map { |_, text| text }], [[], [report::BATTLE_TEXT]])
$in_world = true
report.forget("a test")
check("forgetting a waiting report drops its screenshot", $calls.last.first, "mp_report_drop_snap")
reset

# The map busy at the press, and a menu that cannot be left.
SceneManager.scene = Scene_Map.new
$map_free = false
$pressed = 0x72
frame
check("on a busy map the box says the form opens once the player is free", [$notices.map { |_, text| text }, $called], [[report::BUSY_TEXT], []])
$map_free = true
frame
check("which it then does", $called, [Scene_MpBugReport])
reset
SceneManager.scene = Scene_MpStoryChoices.new
$pressed = 0x72
frame
check("the screen of the story's choices is not left for the form", $called, [])
SceneManager.scene = Scene_Title.new
frame
check("a waiting report is forgotten once the game went to the title screen", [$calls.last.first, report.instance_variable_get(:@pending)], ["mp_report_drop_snap", nil])
reset

# Refusals.
$pressed = 0x72
frame
check("the title screen opens no report", [$called, $calls, $sounds], [[], [], []])
SceneManager.scene = Scene_Map.new
$mgq_text_input = true
$pressed = 0x72
frame
check("nor does a press while the player types", [$called, $calls], [[], []])
$mgq_text_input = false
$share = false
$pressed = 0x72
frame
check("without a name the box says how to choose one", [$called, $notices.last[1], $sounds], [[], report::NO_NAME_REFUSAL, ["buzzer"]])
$share = true
SceneManager.scene = Scene_MpBugReport.allocate
$pressed = 0x72
frame
check("nor while the form is open", [$called, $calls], [[], []])
reset

# A form another scene took the place of is forgotten, so later reports are not refused.
SceneManager.scene = Scene_Menu.new
$pressed = 0x72
frame
SceneManager.scene = Scene_Menu.new
frame
check("a form that never opened is forgotten with its screenshot", [report.take_opening, $calls.last.first], [nil, "mp_report_drop_snap"])
reset

# The action wheel's choice: the screenshot once the wheel faded out.
SceneManager.scene = Scene_Map.new
option = $wheel.first[1].call
check("the wheel offers Report a Bug", [option.text, option.run.nil?], ["Report a Bug", false])
option.run.call
check("the screenshot waits for the wheel to fade out", $calls, [])
(report.wheel_frames - 1).times { frame }
check("still none a frame before it is gone", [$calls, $called], [[], []])
frame
check("then it is taken and the form opens", [$calls.map(&:first), $called], [["mp_report_snap"], [Scene_MpBugReport]])
reset

# A screenshot that fails leaves the report without one.
$snap_fails = true
SceneManager.scene = Scene_Menu.new
$pressed = 0x72
frame
check("a screenshot that fails opens the form without one", [$called, report.take_opening[:snapped]], [[Scene_MpBugReport], false])
$snap_fails = false
$results["mp_report_snap"] = 0
SceneManager.scene = Scene_Menu.new
$pressed = 0x72
frame
check("as does one the DLL did not keep", [report.take_opening[:snapped], $bitmaps.last.disposed?], [false, true])
$results.delete("mp_report_snap")
reset

# The form.
form = report.form(true)
check("the form: title, text, both attachments on one row, and the button", form.fields.map { |field| [field.key, field.kind, field.side] },
      [[:title, :text, nil], [:text, :area, nil], [:screenshot, :check, :left], [:logs, :check, :right], [:send, :button, nil]])
check("the title takes 100 characters, the text 2000 in about 6 lines",
      [form.fields[0].max_chars, form.fields[1].max_chars, form.fields[1].lines], [100, 2000, 6])
check("both attachments start ticked", [form[:screenshot], form[:logs]], [true, true])
check("without a screenshot only the logs", report.form(false).fields.map { |field| [field.key, field.side] }, [[:title, nil], [:text, nil], [:logs, nil], [:send, nil]])
check("an empty title keeps the form from being sent", form.problem, [0, report::TITLE_MISSING])
form[:title] = "Formation stays shut"
check("then the empty text", form.problem, [1, report::TEXT_MISSING])

# Sending.
done = { :facts => [["Mod", "0.6.3"], ["Where", "Scene_Map, map 154"]], :details => [["Player", "Player A (0123abcd)"]], :snapped => true }
check("a report is sent", report.send_report(done, "Formation stays shut", "After the meeting.", true, true), nil)
sent = $calls.last
check("with its texts ended for the DLL, the facts and details as lines, and both attachments",
      sent, ["mp_report_send", ["Formation stays shut\0", "After the meeting.\0", "Mod\t0.6.3\nWhere\tScene_Map, map 154\0", "Player\tPlayer A (0123abcd)\0", 3]])
check("the box says it is being sent", $notices.last, [:bug_report, report::SENDING_TEXT, report::NOTICE_FRAMES])
check("a second one is refused while it is sent", report.send_report(done, "T", "X", true, true), report::SENDING_REFUSAL)
check("as is the wheel's choice", $wheel.first[1].call.refusal, report::SENDING_REFUSAL)
SceneManager.scene = Scene_Map.new
$pressed = 0x72
frame
check("and the hotkey", $notices.last[1], report::SENDING_REFUSAL)

# The outcome.
$state = "sending"
reset
(report::POLL_FRAMES - 1).times { frame }
check("the state is read every half second", $notices, [])
$state = "sent\t42\thttps://github.com/Pauliinchen/MGQ-Online/issues/42"
$shown = false
report::POLL_FRAMES.times { frame }
check("an outcome waits while the box hides, as in a battle", [$notices, report.sending?], [[], false])
$shown = true
frame
check("then the box thanks the player with the issue's number", $notices.last[1], "Bug report sent as issue #42. Thank you!")
report.instance_variable_set(:@sending, true)
outcomes = [["rate", "too many"], ["off", "off"], ["busy", "busy"], ["http500", "GitHub refused the report"], ["unreachable", ""]].map do |code, reason|
  report.instance_variable_set(:@sending, true)
  $state = "failed\t#{code}\t#{reason}"
  report::POLL_FRAMES.times { frame }
  $notices.last[1]
end
check("a failure says why, in friendly words for the rate limit, a relay without reports and a busy one", outcomes,
      ["The bug report failed: you sent several reports in a short time. Try again in an hour.",
       "The bug report failed: the relay takes no bug reports right now.",
       "The bug report failed: the relay is busy with other bug reports. Try again in a minute.",
       "The bug report failed: GitHub refused the report", "The bug report failed: unreachable"])
reset

# The flags and the refusals of sending.
report.send_report(done, "T", "X", false, true)
report.instance_variable_set(:@sending, false)
report.send_report({ :facts => [], :details => [], :snapped => false }, "T", "X", true, false)
report.instance_variable_set(:@sending, false)
check("unticked attachments and a missing screenshot leave their bits out", $calls.map { |_, args| args[4] }, [2, 0])
$results["mp_report_send"] = 0
check("a send the DLL did not start says so and keeps nothing sending", [report.send_report(done, "T", "X", true, true), report.sending?],
      [report::NOT_STARTED_REFUSAL, false])
$results.delete("mp_report_send")
$share = false
check("without a name nothing is sent", report.send_report(done, "T", "X", true, true), report::NO_NAME_REFUSAL)
$share = true
reset

# The form's screen, with its window standing in.
class FakeForm
  attr_accessor :index, :active
  attr_reader :form, :redrawn
  def initialize(form); @form = form; @index = 0; @active = true; @redrawn = 0; end
  def field; @form.fields[@index]; end
  def select(index); @index = index; end
  def activate; @active = true; end
  def refresh; end
  def redraw_current_item; @redrawn += 1; end
  def current_area_spans(_text); [[0, 0]]; end
end
class FakeInfo
  attr_reader :lines
  def show(lines); @lines = lines; end
end

# Builds the form's screen without its windows, for a report with a screenshot.
#
# @return [Scene_MpBugReport] The screen.
def new_screen
  scene = Scene_MpBugReport.allocate
  form = MGQ_MpBugReport.form(true)
  scene.instance_variable_set(:@report, { :facts => [["Mod", "0.6.3"]], :details => [], :snapped => true })
  scene.instance_variable_set(:@form, form)
  scene.instance_variable_set(:@form_window, FakeForm.new(form))
  scene.instance_variable_set(:@info_window, FakeInfo.new)
  scene
end

scene = new_screen
window = scene.instance_variable_get(:@form_window)
info = scene.instance_variable_get(:@info_window)
form = scene.instance_variable_get(:@form)
scene.update
check("the lines above the form say who sees what, then the field's hint", info.lines, [report::HELP, report::TITLE_HINT])
# The form window deactivates itself before it calls on_field, as the game's windows do.
window.active = false
scene.on_field
check("confirm on the title types into it in place", [$typing_on, form.editing, info.lines[1]], [true, :title, Scene_MpWorlds::TYPING_HINT])
$typed = "Formation stays shut\r"
$held = [:C]
scene.update
check("Enter keeps what was typed and stops the typing", [form[:title], form.editing, $typing_on], ["Formation stays shut", nil, false])
scene.update
check("the form waits until the press that ended the typing is let go", window.active, false)
$held = []
scene.update
check("then takes the cursor again", window.active, true)
scene.on_field
$typed = "xx\e"
scene.update
check("Escape puts the text back as it was", [form[:title], form.editing], ["Formation stays shut", nil])
scene.on_field
$typed = "yy"
scene.update
$numpad = true
scene.update
$numpad = false
check("the numpad's 0 leaves the box as Escape does", [form[:title], form.editing], ["Formation stays shut", nil])
scene.on_field
$typed = "#{'z' * 120}\r"
scene.update
check("the title takes 100 characters at most", form[:title].size, 100)
form[:title] = "Formation stays shut"
window.index = 3
scene.on_field
check("confirm on Attach the logs unticks it", form[:logs], false)
window.index = 4
window.active = false
scene.on_field
check("sending without a text points at it and says why", [window.index, info.lines[1], $sounds.last], [1, report::TEXT_MISSING, "buzzer"])
form[:text] = "  After the meeting I cannot change my formation.  "
window.index = 4
scene.on_field
check("a filled form is sent tidied, without the logs, and closes", [$calls.last[1][1], $calls.last[1][4], $returned > 0],
      ["After the meeting I cannot change my formation.\0", 1, true])
returned = $returned
scene.terminate
check("the form that sent its report keeps the screenshot for it", $calls.map(&:first).include?("mp_report_drop_snap"), false)
report.instance_variable_set(:@sending, false)
reset

scene = new_screen
window = scene.instance_variable_get(:@form_window)
$buttons = [:B]
scene.update
scene.terminate
check("cancel leaves the form and drops the screenshot", [$returned, $calls.map(&:first)], [returned + 1, ["mp_report_drop_snap"]])
reset
scene = new_screen
$numpad = true
scene.update
$numpad = false
check("as does the numpad's 0", $returned, returned + 2)
reset
$running = false
scene = new_screen
scene.on_field
check("without the keyboard the box is not typed into, and the form says why",
      [scene.instance_variable_get(:@form).editing, scene.instance_variable_get(:@info_window).lines[1]], [nil, report::NO_KEYBOARD_REFUSAL])
$running = true

# The texts.
check("the hotkey's help names it a hotkey", MGQ_MpHotkeys::BINDINGS[:bug_report].help.start_with?("The hotkey"), true)
