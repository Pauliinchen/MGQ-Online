#----------------------------------------------------------------
#  world_open_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Expected the longer call of mp_dir_create, which takes a Raid World's difficulty
#                            - Checked a Raid World's difficulty in the list, the details and world.ini, and what the open world tells of it
#      Paulinchen  2026-10-08: Checked Raid Worlds: their type and companion sharing in the list, details and world.ini, their place and red, raid? and companion_sharing, the form's switches and their arrows
#                            - Checked the update offer in place of the update notice, and the world screen opening after the update
#                            - Checked that the update offer keeps the game open under Wine
#                            - Checked that an outdated game offers the update for a Discord invite and for the entry after a restart for mods
#      Paulinchen  2026-10-07: Checked that the worlds on this PC and the favourites are read once until one changes
#                            - Looked each DLL call's signature up in the export table of Multiplayer.rb
#                            - Checked that a form's switch turns round between its outcomes
#      Paulinchen  2026-10-06: Checked a world's password typed in place, an invite's failed code giving way to the password,
#                              a full world kept shut to players with saves of it, and an invite waiting for an open window
#                            - Refused a DLL call whose arguments differ from its signature
#                            - Checked a Discord invite into a world, which opens the world screen and enters the world without its password
#                            - Checked that backing out of a world's new game, which asks something first, leaves the world
#                            - Loaded world_mods.rbx, which the world screen calls
#      Paulinchen  2026-10-04: Checked that an outdated game enters no world and is told so in a message box until the player closes it
#                            - Followed the scripts to their new names, without mp_
#                            - Read the details from their panels
#                            - Expected a hidden world's id alone in the form that adds it
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Checked the seats a world code tells
#                            - Created
#
#----------------------------------------------------------------

# Checks worlds without a password, featured worlds and Raid Worlds (world.rbx): the forms taking an
# empty password, the directory's flags for them, entering a world without a password without being
# asked, the featured worlds' and Raid Worlds' place and colour in the list, what the details say,
# what world.ini keeps of a Raid World and what the scripts ask of it, the form's switches, an
# outdated game kept out and offered the update, and the world screen opening after it.

require_relative "support"
require "tmpdir"

# Stand-ins for the game.
class Scene_Base; def return_scene; $returned = true; end; end
class Scene_MenuBase < Scene_Base; end
class Scene_Load < Scene_Base; end
class Window_Base; def initialize(*); end; end
class Window_Selectable < Window_Base; end
class Window_Command < Window_Selectable; end
class Window_NameEdit < Window_Base; end
class Window_NameInput < Window_Selectable; end
class Color; def initialize(*); end; end
class Sprite; def initialize(*); end; end
Rect = Struct.new(:x, :y, :width, :height)
class Scene_Title; def start; end; def create_command_window; end; def close_command_window; end; def update; end; def terminate; end; end
class Window_TitleCommand; def make_command_list; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
module SceneManager
  def self.call(scene); $called = scene; end
  def self.scene; Object.new.tap { |scene| def scene.prepare(*); end }; end
end
module DataManager; def self.save_system; end; end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$dll = {}
$outdated = false
module MGQ_Multiplayer
  UPDATE_MESSAGE = "Update."
  def self.available?; true; end
  def self.outdated?; $outdated; end
  def self.newer_version; $outdated ? "9.9.9" : nil; end
  def self.clean(text); text; end
  def self.path(name); name; end
  module Log; def self.write(_message); end; end
  module Player; def self.share; end; def self.name; "Me"; end; end
  module Ini; def self.read(_path); {}; end; end
  module Capture
    def self.start(owner); $capture = owner; end
    def self.stop(owner); $capture = nil if $capture == owner; end
    def self.trigger?(button); $pressed == button; end
  end
  module Mouse; def self.clicked?; false; end; end
  module Link
    Function = Struct.new(:name, :signature) do
      def call(*args); check_dll_call(name, args); $calls << [name, signature, args]; 1; end
    end
    def self.function(name); Function.new(name, dll_signature(name)); end
    def self.read(name, _size); $dll[name].to_s; end
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end

load_script "world_save_distribution"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_mods"
load_script "world_text"
load_script "world_screen"

# A small window of the world screen: keeps the commands it opened with and whether it takes input.
class FakeChoice
  # Whether it takes input.
  attr_reader :active

  # Opens with commands and takes input.
  #
  # @param _choices [Array<Array>] The commands.
  def start(_choices); @active = true; end

  # Closes.
  def finish; @active = false; end

  # Takes input.
  def activate; @active = true; end

  # Takes no input.
  def deactivate; @active = false; end

  # The cursor's row.
  #
  # @return [Integer] -1, no cursor.
  def index; -1; end
end

# The lines at the top of the world screen: keeps what they show.
class FakeInfo
  # Shows lines.
  #
  # @param _lines [Array<String, nil>] The lines.
  def show(_lines); end
end

# Builds the world screen without its windows.
#
# @return [Scene_MpWorlds] The screen.
def new_scene
  scene = Scene_MpWorlds.allocate
  [:@actions_window, :@members_window, :@confirm_window, :@start_window, :@list_window, :@form_window].each { |name| scene.instance_variable_set(name, FakeChoice.new) }
  scene.instance_variable_set(:@info_window, FakeInfo.new)
  scene
end

# The forms.
form = MGQ_MpWorld::Form.create
form[:name] = "Open Fields"
check("a new world needs no password", form.problem, nil)
password = form.fields.find { |field| field.key == :password }
check("a password keeps its spaces", form.check(password, " a b "), [" a b ", nil])
join = MGQ_MpWorld::Form.join
join[:id] = "a" * 32
check("a hidden world is added by its id alone", [join.problem, join.fields.map { |field| field.key }], [nil, [:id, :confirm]])
switch = MGQ_MpWorld::Form::Field.new(:way, :switch, "Way", 0, "Which way.", :choices => %w(Left Middle Right), :note => lambda { |_, index| "Picked #{index}" })
ways = MGQ_MpWorld::Form.new("Ways", [switch], :way => 0)
check("a switch turns round between its outcomes, with the line of the one picked", [ways.turn(switch, -1), switch.note_of(ways), ways.turn(switch, 1)], [2, "Picked 2", 0])
MGQ_MpWorld::Directory.create("Open Fields", "", 4, false, false, "")
check("an empty password goes to the DLL as it is", $calls.last[2][1], "\0")

# The directory.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tw1\t4\t0\tc\t0\tC\tPlain\tnone\t0\t0\t0\t0\n" \
  "world\tw2\t4\t0\tc\t0\tGlobal\tGolden\tnone\t0\t0\t1\t1\n" \
  "world\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\t0\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds have no password", listed.map { |world| world.open }, [false, true, false])
check("and which are featured", listed.map { |world| world.featured }, [false, true, false])

# The worlds on this PC and the favourites are read once, until one is made, written, deleted or
# marked.
ini = {}
reads = [0]
MGQ_Multiplayer::Ini.define_singleton_method(:read) { |path| reads[0] += 1; (ini[path] || {}).dup }
MGQ_Multiplayer::Ini.define_singleton_method(:write) { |path, values| ini[path] = values.dup; true }
dll_id_of = MGQ_MpWorld::Link.method(:id_of)
MGQ_MpWorld::Link.define_singleton_method(:id_of) { |code| code[/\A[0-9a-f]{12}/] }
Dir.mktmpdir do |root|
  Dir.chdir(root) do
    FileUtils.mkdir_p(File.join("Patch", "Multiplayer"))
    check("without a Worlds folder there is no world", MGQ_MpWorld::World.all, [])
    made = MGQ_MpWorld::World.found("0123456789ab;token;relay;4", "First", "w1")
    check("a world made is listed", MGQ_MpWorld::World.all.map { |world| [world.id, world.name] }, [["0123456789ab", "First"]])
    before = reads[0]
    3.times { MGQ_MpWorld::World.all }
    check("and the folders are read once for it", reads[0], before)
    made.played!
    check("a world written is read again", [MGQ_MpWorld::World.all[0].played_at.nil?, reads[0] > before], [false, true])
    made.delete
    check("a world deleted is gone from the list", MGQ_MpWorld::World.all, [])
    before = reads[0]
    favourites = [MGQ_MpWorld::Favourites.all, MGQ_MpWorld::Favourites.all]
    check("the favourites are read once too", [favourites, reads[0] - before], [[[], []], 1])
    check("a world marked is a favourite at once", [MGQ_MpWorld::Favourites.toggle("w1"), MGQ_MpWorld::Favourites.all], [true, ["w1"]])
    check("and no longer once unmarked", [MGQ_MpWorld::Favourites.toggle("w1"), MGQ_MpWorld::Favourites.all], [false, []])
  end
end
MGQ_MpWorld::Link.define_singleton_method(:id_of, dll_id_of)
MGQ_MpWorld::World.forget
MGQ_MpWorld::Favourites.forget

# The list's order.
MGQ_MpWorld::Favourites.define_singleton_method(:all) { ["w3"] }
MGQ_MpWorld::World.define_singleton_method(:all) { [] }
entries = MGQ_MpWorld.entries(listed, true)
check("favourites come first, then featured worlds", entries.map { |entry| entry.name }, ["Old", "Golden", "Plain"])
check("an entry tells whether it is featured or open", [entries[1].featured?, entries[1].open?, entries[2].featured?], [true, true, false])
gone = MGQ_MpWorld::Entry.new("w9", "Gone", nil, nil, false, true)
check("a world the directory no longer lists is neither", [gone.featured?, gone.open?], [false, false])

# Entering.
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
$called = nil
$calls.clear
scene.on_enter
check("a world without a password is opened at once", [$calls.last[0], $calls.last[2], $called], ["mp_dir_unlock", ["w2\0", "\0"], nil])
check("while the screen waits for it", scene.instance_variable_get(:@busy), "unlock")

# What typing in place needs.
module MGQ_Multiplayer
  module Background; def self.running?; true; end; end
  module Key; def self.pressed?(_code); false; end; def self.triggered?(code); pressed?(code); end; end
  module Link
    def self.typing(on); $typing = on; end
    def self.take_typed; typed = $typed.to_s; $typed = nil; [typed, typed.size]; end
  end
end
module Input; def self.trigger?(_button); false; end; def self.press?(_button); false; end; end

# The form window of the world screen: shows a form and keeps the field the cursor is on.
class FakeForm < FakeChoice
  # The form shown.
  attr_accessor :form

  # Picks a row.
  #
  # @param index [Integer] The row.
  def select(index); @row = index; end

  # The cursor's row.
  #
  # @return [Integer] The row picked last, the first before any.
  def index; @row || 0; end

  # The field the cursor is on.
  #
  # @return [MGQ_MpWorld::Form::Field] The field.
  def field; form.fields[index]; end

  # Takes the cursor off.
  def unselect; @row = nil; end

  # Draws nothing.
  def refresh; end

  # Draws nothing.
  def redraw_current_item; end
end

# Builds the world screen with a form window and no forms yet.
#
# @return [Scene_MpWorlds] The screen.
def form_scene
  scene = new_scene
  scene.instance_variable_set(:@form_window, FakeForm.new)
  scene.instance_variable_set(:@forms, {})
  scene
end

scene = form_scene
scene.instance_variable_set(:@entry, entries[2])
$called = nil
scene.on_enter
check("a world with a password asks for it in a form typed in place", [$called, scene.form.title, scene.form.editing, $typing], [nil, "Enter Plain", :password, true])
$calls.clear
$typed = "secret\r"
scene.update_typing
check("Enter opens the world with it", [$calls.last[0], $calls.last[2], scene.instance_variable_get(:@busy), $typing], ["mp_dir_unlock", ["w1\0", "secret\0"], "unlock", false])

scene = form_scene
scene.instance_variable_set(:@entry, entries[2])
scene.instance_variable_set(:@invite_codes, { "w1" => "mgqmp2;old;r1;4" })
scene.on_enter
check("an invite's code opens the world instead of its password", $calls.last[0], "mp_dir_unlock_code")
$dll["mp_dir_action"] = "state=failed\nerror=Expired.\n\n"
scene.follow_action
$dll["mp_dir_action"] = nil
scene.on_enter
check("once it failed, the password is asked", scene.form && scene.form.editing, :password)

full = entries[2].listed.dup
full.online = full.seats
local = MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "name" => "Plain")
scene = new_scene
scene.instance_variable_set(:@me, "me")
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Plain", full, local, false, false))
$sounds.clear
$calls.clear
scene.on_enter
check("a full world keeps out players with saves of it too", [$sounds.last, $calls, MGQ_MpWorld.open?], ["buzzer", [], false])
full.members = [MGQ_MpWorld::Directory::Member.new("me", true, "Me")]
check("unless the relay still counts the player among those online", scene.full?(full), false)

# A details window that draws on nothing and keeps the texts it draws.
#
# @param width [Integer] The width of its contents.
# @param height [Integer] The height of its contents.
# @return [Array] The window and the texts drawn, which fill as it shows a world.
def new_detail(width, height)
  detail = Window_MpWorldDetail.allocate
  texts = []
  font = Struct.new(:size).new(24)
  canvas = Struct.new(:font).new(font)
  canvas.define_singleton_method(:clear) { texts.clear }
  canvas.define_singleton_method(:fill_rect) { |*| }
  detail.define_singleton_method(:contents) { canvas }
  detail.define_singleton_method(:contents_width) { width }
  detail.define_singleton_method(:contents_height) { height }
  detail.define_singleton_method(:change_color) { |*| }
  detail.define_singleton_method(:reset_font_settings) { font.size = 24 }
  detail.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * font.size / 2) }
  detail.define_singleton_method(:draw_text) { |*args| texts << args[4] }
  %w[system_color normal_color power_up_color crisis_color].each { |name| detail.define_singleton_method(name) { name } }
  [detail, texts]
end

# Finds a value of the details by its label.
#
# @param panels [Array<Window_MpWorldDetail::Panel>] The panels.
# @param label [String] The label.
# @return [Window_MpWorldDetail::Cell, nil] The cell.
def cell_of(panels, label)
  panels.map { |panel| panel.rows }.flatten.compact.find { |cell| cell.label == label }
end

# What the details say.
detail, texts = new_detail(386, 336)
panels = detail.panels(entries[1], "me")
check("a featured world says so beside its heading", [panels[0].title, panels[0].note], ["World", "featured: one of the relay's own"])
check("a world without a password needs none", cell_of(panels, "Password").text, "None")
check("made by the admin tool's player", cell_of(panels, "Creator").text, "Global")
check("a world of the player's own is made by them", cell_of(detail.panels(entries[1], "c"), "Creator").text, "You")
check("a world the directory no longer lists says only so", detail.panels(gone, "me").map { |panel| panel.rows.flatten.map { |cell| cell.text } }, [["Only on this PC: deleted, or you were removed"]])
detail.show(entries[1], "me")
check("the name is drawn with when it was played, then the headings in capitals", [texts[0, 2], texts.include?("WORLD"), texts.include?("PLAYERS"), texts.include?("DESCRIPTION")], [["not entered yet", "Golden"], true, true, true])
check("a world without a description says so at the bottom", texts.last, "No description.")

# The seats, which the world code tells.
check("a world's code tells its seats", MGQ_MpWorld::World.new("abcdef012345", "code" => "mgqmp2;abcdefghjkmnpqrs;r1;8").seats, 8)
check("a code without them tells none", MGQ_MpWorld::World.new("abcdef012345", {}).seats, 0)

# Raid Worlds: the type and companion sharing the list reads, their place and colour, the details,
# world.ini, what every script asks of the open world, and the new world's form.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tr1\t4\t0\tc\t0\tC\tRaid Night\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\traid\tstory\t1\n" \
  "world\tr2\t4\t0\tc\t0\tGlobal\tRaid Gold\tnone\t0\t0\t1\t1\t0\t\t\t\t\t\traid\tall\t\n" \
  "world\tw1\t4\t0\tc\t0\tC\tPlain\tnone\t0\t0\t0\t0\t0\t\t\t\t\t\tclassic\toff\t3\n" \
  "world\tw3\t4\t0\tc\t0\tC\tOld\tnone\t0\t0\n"
_, _, typed, = MGQ_MpWorld::Directory.list
check("the list reads each world's type and companion sharing, Classic sharing none without them",
      typed.map { |world| [world.type, world.share, world.raid?] }, [["raid", "story", true], ["raid", "all", true], ["classic", "off", false], ["classic", "off", false]])
check("and a Raid World's difficulty, none for one without it and for every Classic world", typed.map { |world| world.difficulty }, [1, nil, nil, nil])
raid_entries = MGQ_MpWorld.entries(typed, true)
check("Raid Worlds come above every other world, favourites and featured ones too", raid_entries.map { |entry| entry.name }, ["Raid Gold", "Raid Night", "Old", "Plain"])
raid_local = MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "name" => "Kept", "type" => "raid", "share" => "story")
check("a Raid World the directory no longer lists stays one by its world.ini", [MGQ_MpWorld::Entry.new("r9", "Kept", nil, raid_local, false, true).raid?, gone.raid?], [true, false])

# The colour of a row in the list and of the details' title.
list_window = Window_MpWorldList.allocate
colors = []
list_window.define_singleton_method(:item_rect_for_text) { |_index| Rect.new(0, 0, 200, 24) }
list_window.define_singleton_method(:change_color) { |color, _enabled = true| colors << color }
list_window.define_singleton_method(:draw_text) { |*| }
%w[normal_color crisis_color].each { |name| list_window.define_singleton_method(name) { name } }
list_window.instance_variable_set(:@list, raid_entries.map { |entry| { :ext => entry } })
(0...raid_entries.size).each { |index| list_window.draw_item(index) }
check("a Raid World's row is red, which wins over a featured one's gold and a favourite's colour",
      colors.map { |color| color.equal?(MGQ_MpWorld::RAID_COLOR) ? :red : color }, [:red, :red, "crisis_color", "normal_color"])
detail, = new_detail(386, 336)
title_colors = []
detail.define_singleton_method(:change_color) { |color, _enabled = true| title_colors << color }
detail.draw_title(raid_entries[0])
check("and so is a Raid World's name above its details", title_colors.last.equal?(MGQ_MpWorld::RAID_COLOR), true)
check("whose cells may ask for the red too", detail.color_of(:raid).equal?(MGQ_MpWorld::RAID_COLOR), true)

# The details.
raid_panels = detail.panels(raid_entries[1], "me")
check("the details tell a Raid World and how it shares companions", [cell_of(raid_panels, "Type").text, cell_of(raid_panels, "Type").color, cell_of(raid_panels, "Sharing").text],
      ["Raid", :raid, "Story"])
check("or that it shares story companions and battle recruits", cell_of(detail.panels(raid_entries[0], "me"), "Sharing").text, "Story, recruits")
check("a Raid World's players start at the beginning, on the difficulty it sets", [cell_of(raid_panels, "Start").text, cell_of(raid_panels, "Difficulty").text], ["The beginning", "HARD"])
check("or each on their own in one that sets none", cell_of(detail.panels(raid_entries[0], "me"), "Difficulty").text, "Per player")
check("and a Classic world names no difficulty", cell_of(detail.panels(raid_entries[3], "me"), "Difficulty"), nil)
plain_panels = detail.panels(raid_entries[3], "me")
check("but a Classic world's World panel keeps its three rows, with no type row", [plain_panels[0].rows.size, cell_of(plain_panels, "Type"), raid_panels[0].rows.size], [3, nil, 4])

# world.ini keeps the type and the sharing for a world entered while the directory listed it.
MGQ_MpWorld::Link.define_singleton_method(:id_of) { |code| code[/\A[0-9a-f]{12}/] }
Dir.mktmpdir do |root|
  Dir.chdir(root) do
    FileUtils.mkdir_p(File.join("Patch", "Multiplayer"))
    MGQ_MpWorld::World.found("0123456789ab;token;relay;4", "Raid Night", "r1", "raid", "story", -1)
    kept = ini["Patch/Multiplayer/Worlds/0123456789ab/world.ini"]
    check("world.ini keeps a Raid World's type, companion sharing and difficulty", [kept["type"], kept["share"], kept["difficulty"]], ["raid", "story", -1])
    read_back = MGQ_MpWorld::World.read("0123456789ab")
    check("which read back tell a Raid World", [read_back.raid?, read_back.companion_sharing, read_back.difficulty], [true, :story, -1])
    MGQ_MpWorld::World.found("0123456789ab;token;relay;4", "Raid Night", "r1")
    check("and stay when the world is found again without them", [MGQ_MpWorld::World.read("0123456789ab").raid?, MGQ_MpWorld::World.read("0123456789ab").difficulty], [true, -1])
    read_back.describe("Raid Night", "r1", nil, nil, nil, 3)
    read_back.write
    check("a difficulty the list tells on entry replaces the one kept", MGQ_MpWorld::World.read("0123456789ab").difficulty, 3)
    MGQ_MpWorld::World.found("fedcba987654;token;relay;4", "Plain", "w1", "classic", "off")
    check("a Classic world is kept as one", [MGQ_MpWorld::World.read("fedcba987654").raid?, MGQ_MpWorld::World.read("fedcba987654").companion_sharing], [false, :off])
  end
end
MGQ_MpWorld::Link.define_singleton_method(:id_of, dll_id_of)
MGQ_MpWorld::World.forget
check("a world.ini from before types is Classic", [MGQ_MpWorld::World.new("abcdef012345", "code" => "x").raid?, MGQ_MpWorld::World.new("abcdef012345", "code" => "x").type], [false, nil])

# What every script asks of the open world.
check("outside a world there is no Raid World and no sharing", [MGQ_MpWorld.raid?, MGQ_MpWorld.companion_sharing], [false, :off])
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "raid", "share" => "all"))
check("in a Raid World both tell it", [MGQ_MpWorld.raid?, MGQ_MpWorld.companion_sharing], [true, :all])
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "raid", "share" => "lots"))
check("a sharing this game does not know shares nothing", MGQ_MpWorld.companion_sharing, :off)
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "classic", "share" => "all"))
check("a Classic world is no Raid World and shares nothing", [MGQ_MpWorld.raid?, MGQ_MpWorld.companion_sharing], [false, :off])
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "classic", "difficulty" => "2"))
check("and sets no difficulty, whatever its world.ini says, nor takes one", [MGQ_MpWorld.difficulty, MGQ_MpWorld.take_difficulty(1), MGQ_MpWorld.world.difficulty], [nil, false, 2])
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => "2"))
check("a Raid World tells its difficulty", MGQ_MpWorld.difficulty, 2)
check("and takes a new one the relay tells, keeping it in world.ini", [MGQ_MpWorld.take_difficulty(-2), MGQ_MpWorld.difficulty, ini["Patch/Multiplayer/Worlds/abcdef012345/world.ini"]["difficulty"]], [true, -2, -2])
check("but no value that is no difficulty", [MGQ_MpWorld.take_difficulty(5), MGQ_MpWorld.difficulty], [false, -2])
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "code" => "x", "type" => "raid", "difficulty" => "hard"))
check("a world.ini's difficulty this game does not know is none", MGQ_MpWorld.difficulty, nil)
check("the difficulties carry the game's own names", [MGQ_MpWorld.difficulty_name(-2), MGQ_MpWorld.difficulty_name(0), MGQ_MpWorld.difficulty_name(4), MGQ_MpWorld.difficulty_name(nil)],
      ["VERY EASY", "NORMAL", "PARADOX", nil])
MGQ_MpWorld.instance_variable_set(:@world, nil)

# The new world's form.
raid_form = MGQ_MpWorld::Form.create
type_field = raid_form.fields.find { |field| field.key == :type }
share_field = raid_form.fields.find { |field| field.key == :share }
check("the form has a World type switch beside Hidden, Classic at first", [type_field.kind, type_field.row, type_field.side, type_field.choices, raid_form.type], [:switch, 2, :right, ["Classic", "Raid"], "classic"])
check("and Sharing companions below it, greyed out for a Classic world", [share_field.kind, share_field.row, share_field.choices.size, raid_form.enabled?(share_field), raid_form.share], [:switch, 3, 3, false, "off"])
raid_form[:type] = 1
raid_form[:share] = 1
check("a Raid World brings it back", [raid_form.enabled?(share_field), raid_form.type, raid_form.share], [true, "raid", "story"])
check("whose hints fit the lines at the top", [type_field.hint.size <= 100, share_field.hint.size <= 100], [true, true])
MGQ_MpWorld::Directory.create("Raid Night", "", 4, false, false, "", :type => "raid", :share => "story")
check("create hands the type and the sharing to the DLL", [$calls.last[1], $calls.last[2][12..13]], ["pplllpppplppppl", ["raid\0", "story\0"]])
MGQ_MpWorld::Directory.create("Plain", "", 4, false, false, "", :share => "all")
check("a Classic world shares nothing", $calls.last[2][12..13], ["classic\0", "off\0"])

# Turning the form's switches on the world screen.
scene = form_scene
scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::Form.create })
scene.instance_variable_set(:@form_symbol, :new_world)
form_window = scene.instance_variable_get(:@form_window)
form_window.form = scene.form
form_window.select(scene.form.fields.index { |field| field.key == :type })
$sounds.clear
scene.on_field
check("confirm turns a switch", [scene.form.type, $sounds.last], ["raid", "cursor"])
form_window.select(scene.form.fields.index { |field| field.key == :share })
scene.turn_switch(-1)
check("and an arrow back turns it round", scene.form.share, "all")

# The form window's arrows and switches.
window = Window_MpWorldForm.allocate
window.instance_variable_set(:@form, MGQ_MpWorld::Form.create)
picked = [nil]
window.define_singleton_method(:field) { picked[0] }
turned = []
moved = []
window.on_turn = lambda { |step| turned << step }
window.define_singleton_method(:move_side) { |side| moved << side }
picked[0] = type_field
window.cursor_right
window.cursor_left
check("an arrow away from a switch's neighbour turns it, one toward it moves there", [turned, moved], [[1], [:left]])
picked[0] = share_field
$sounds.clear
window.cursor_right
check("a greyed-out switch buzzes", [turned, $sounds], [[1], ["buzzer"]])
window.form[:type] = 1
window.cursor_left
check("a switch across its row turns both ways", turned, [1, -1])
picked[0] = window.form.fields.find { |field| field.key == :password }
window.cursor_right
check("other fields move as before", moved, [:left, :right])

# A switch's label takes the field's width, else the window's, which a window of its own may widen.
class WideForm < Window_MpWorldForm
  # Width of the switches' names.
  LABEL_WIDTH = 150
end
# Builds a form window that draws on nothing and keeps the label widths it draws.
#
# @param kind [Class] Window_MpWorldForm or a window of its own.
# @param form [MGQ_MpWorld::Form] The form.
# @return [Array] The window and the texts drawn with their widths.
def drawing_form(kind, form)
  window = kind.allocate
  window.instance_variable_set(:@form, form)
  drawn = []
  font = Struct.new(:size).new(24)
  canvas = Struct.new(:font).new(font)
  canvas.define_singleton_method(:fill_rect) { |*| }
  window.define_singleton_method(:contents) { canvas }
  window.define_singleton_method(:change_color) { |*| }
  window.define_singleton_method(:cut) { |text, _width| text }
  window.define_singleton_method(:draw_text) { |*args| drawn << [args[2], args[4]] }
  %w[system_color normal_color].each { |name| window.define_singleton_method(name) { name } }
  [window, drawn]
end
plain_window, plain_drawn = drawing_form(Window_MpWorldForm, raid_form)
plain_window.draw_switch(Rect.new(0, 0, 188, 21), type_field, true)
plain_window.draw_switch(Rect.new(0, 0, 380, 21), share_field, true)
check("the world type's label is narrower, Sharing companions takes the window's", [plain_drawn[0], plain_drawn[2]], [[70, "World type"], [84, "Sharing companions"]])
check("each shows its outcome between arrows", [plain_drawn[1][1], plain_drawn[3][1]], ["< Raid >", "< Story companions >"])
noted = MGQ_MpWorld::Form::Field.new(:way, :switch, "Way", 0, "Which way.", :choices => %w(Left Right), :note => lambda { |_, index| "Picked #{index}" })
wide_window, wide_drawn = drawing_form(WideForm, MGQ_MpWorld::Form.new("Ways", [noted], :way => 1))
wide_window.draw_switch(Rect.new(0, 0, 380, 37), noted, true)
check("a window of its own draws its names wider, and a switch's line below it", wide_drawn, [[150, "Way"], [380 - 150 - 8, "< Right >"], [376, "Picked 1"]])
check("which makes its row higher than a switch without one", [wide_window.height_of(noted), wide_window.height_of(type_field)], [21 + 16, 21])

# An outdated game.
$outdated = true
$calls.clear
check("an outdated game enters no world", [MGQ_MpWorld.start(MGQ_MpWorld::World.new("abcdef012345", {}), new_scene), MGQ_MpWorld.open?, $calls], ["Update.", false, []])
title = Window_TitleCommand.new
title.instance_variable_set(:@list, [{ :symbol => :continue }])
MGQ_MpWorld.add_title_command(title)
check("and finds the title command enabled", title.instance_variable_get(:@list)[1].values_at(:symbol, :enabled), [:mgq_mp_world, true])

# The update offer, a message box that draws on nothing, over the title's commands.
class Sprite_MpMessageBox
  attr_accessor :visible
  attr_reader :shown
  def initialize; end
  def show(*args); @shown = args; @visible = true; end
  def dispose; end
end
class TitleMenu
  attr_reader :active
  def disposed?; false; end
  def activate; @active = true; end
end
module SceneManager; def self.exit; $exited = true; end; end
title_scene = Scene_Title.new
title_scene.instance_variable_set(:@command_window, TitleMenu.new)
offer = MGQ_MpWorld::UpdateOffer
$called = nil
$calls.clear
MGQ_MpWorld.open_world_screen(title_scene)
check("picking Multiplayer offers the update in place of the world screen and holds the buttons",
      [$called, offer.shown?, offer.instance_variable_get(:@box).shown[0], $capture], [nil, true, "Monster Girl Quest! Online 9.9.9 is out", :update_offer])
offer.update
check("and stays while nothing is pressed", [offer.shown?, $calls], [true, []])
$pressed = :B
offer.update
$pressed = nil
check("cancel closes it and gives the buttons back to the title's commands", [offer.shown?, $capture, title_scene.instance_variable_get(:@command_window).active], [false, nil, true])
MGQ_MpWorld.open_world_screen(title_scene)
MGQ_Multiplayer::Key.define_singleton_method(:pressed?) { |code| code == 0x2D }
offer.update
MGQ_Multiplayer::Key.define_singleton_method(:pressed?) { |_code| false }
check("the numpad's 0 closes it too, also with Num Lock off", [offer.shown?, $capture], [false, nil])
MGQ_MpWorld.open_world_screen(title_scene)
$pressed = :C
offer.update
$pressed = nil
check("confirm starts the updater and closes the game", [$calls.map(&:first), $exited], [["mp_update_game"], true])
$exited = nil
offer.hide
module MGQ_Multiplayer; module Link; class << self; alias working_function function; end; end; end
MGQ_Multiplayer::Link.define_singleton_method(:function) { |name| Struct.new(:name) { def call(*); 0; end }.new(name) }
MGQ_MpWorld.open_world_screen(title_scene)
$pressed = :C
offer.update
check("an updater that cannot start keeps the game open and tells how to update by hand",
      [$exited, offer.shown?, offer.instance_variable_get(:@box).shown[1]], [nil, true, "The updater could not start. Close the game and run Patch\\Multiplayer\\Update.bat to update."])
offer.update
$pressed = nil
check("confirm then closes the box", offer.shown?, false)
MGQ_Multiplayer::Link.define_singleton_method(:function) { |name| Struct.new(:name) { def call(*); 2; end }.new(name) }
MGQ_MpWorld.open_world_screen(title_scene)
$pressed = :C
offer.update
$pressed = nil
check("under Wine the game stays open and the box tells to update by hand", [$exited, offer.instance_variable_get(:@box).shown[1]], [nil, MGQ_MpWorld::UpdateOffer::WINE_TEXT])
offer.hide
MGQ_Multiplayer::Link.define_singleton_method(:function) { |name| working_function(name) }
offer.hide
$outdated = false

# The game started again by the updater opens the world screen once.
ENV[MGQ_MpWorld::OPEN_AFTER_UPDATE] = "1"
$called = nil
check("after the update the title screen opens the world screen", [MGQ_MpWorld.open_after_update(title_scene), $called], [true, Scene_MpWorlds])
$called = nil
check("but only once", [MGQ_MpWorld.open_after_update(title_scene), $called, ENV[MGQ_MpWorld::OPEN_AFTER_UPDATE]], [false, nil, nil])

# A world's new game that asks something first, such as a hero, and the player backing out of it.
class TitleCommands
  attr_reader :active
  def disposed?; false; end
  def activate; @active = true; end
  def deactivate; @active = false; end
end
class Scene_Title
  def command_new_game; @asked = true; @command_window.deactivate; end
  def asked?; @asked; end
  def scene_changing?; false; end
end
asking = Scene_Title.new
asking.instance_variable_set(:@command_window, TitleCommands.new)
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", {}))
MGQ_MpWorld.instance_variable_set(:@pending, :new_game)
MGQ_MpWorld.on_title_update(asking)
MGQ_MpWorld.on_title_update(asking)
check("a new game that asks first keeps the world open while the question stands", [asking.asked?, MGQ_MpWorld.open?], [true, true])
asking.instance_variable_get(:@command_window).activate
MGQ_MpWorld.on_title_update(asking)
check("backing out to the title's commands leaves the world", MGQ_MpWorld.open?, false)
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", {}))
MGQ_MpWorld.instance_variable_set(:@pending, :new_game)
asking.instance_variable_get(:@command_window).deactivate
MGQ_MpWorld.on_title_update(asking)
MGQ_MpWorld.new_game_started
asking.instance_variable_get(:@command_window).activate
MGQ_MpWorld.on_title_update(asking)
check("a new game that started keeps the world", MGQ_MpWorld.open?, true)
MGQ_MpWorld.instance_variable_set(:@world, nil)

# A Discord invite into a world, which carries the world code.
MGQ_MpWorld::Link.define_singleton_method(:directory_id) { |code| code.start_with?("mgqmp2;") ? "w3" : nil }
added = []
MGQ_MpWorld::Added.define_singleton_method(:add) { |id| added << id }
check("an invite that is no world code is left to PvP battles", MGQ_MpWorld::Invite.receive("mgqmp1;abcdefghjk;47625;203.0.113.7"), false)
MGQ_MpWorld.instance_variable_set(:@world, MGQ_MpWorld::World.new("abcdef012345", "world" => "w3"))
check("an invite into the world already open is dropped", [MGQ_MpWorld::Invite.receive("mgqmp2;token;r1;4"), MGQ_MpWorld::Invite.take], [true, nil])
MGQ_MpWorld.instance_variable_set(:@world, nil)
check("an invite into a world is taken", MGQ_MpWorld::Invite.receive("mgqmp2;token;r1;4"), true)
$called = nil
MGQ_MpWorld.on_title_update(asking)
check("the title screen opens the world screen for it", $called, Scene_MpWorlds)

invited = new_scene
invited.take_invite
check("the world screen takes it once and adds the world to the list, since a hidden one needs that", [added, MGQ_MpWorld::Invite.take], [["w3"], nil])
invited.instance_variable_get(:@actions_window).start([])
$calls.clear
invited.join_invited(entries, "ready")
check("it waits while a window is open", $calls, [])
invited.instance_variable_get(:@actions_window).finish
$calls.clear
invited.join_invited(entries, "loading")
check("it waits for the list", $calls, [])
invited.join_invited(entries.reject { |entry| entry.id == "w3" }, "ready")
check("a list without the world is fetched once more", [$calls.map(&:first), invited.instance_variable_get(:@entry)], [["mp_dir_watch", "mp_dir_refresh"], nil])
$calls.clear
invited.join_invited(entries, "ready")
check("then the world is opened with the invite instead of its password", [$calls.last[0], $calls.last[2], $called], ["mp_dir_unlock_code", ["mgqmp2;token;r1;4\0"], Scene_MpWorlds])
$calls.clear
invited.join_invited(entries, "ready")
check("once", $calls, [])

# An outdated game offers the update on the title screen where it would open the world screen on
# its own: for a Discord invite, and to enter a world again after a restart for its mods.
class TitleMenu; def deactivate; @active = false; end; end
$outdated = true
offering = Scene_Title.new
offering.instance_variable_set(:@command_window, TitleMenu.new)
offer.hide
MGQ_MpWorld::Invite.receive("mgqmp2;token;r1;4")
$called = nil
MGQ_MpWorld.on_title_update(offering)
check("an outdated game offers the update for a Discord invite instead of opening the world screen, and drops the invite",
      [$called, offer.shown?, offer.instance_variable_get(:@box).shown[0], offering.instance_variable_get(:@command_window).active, MGQ_MpWorld::Invite.take],
      [nil, true, "Monster Girl Quest! Online 9.9.9 is out", false, nil])
$pressed = :B
offer.update
$pressed = nil
check("closing it gives the title's commands back", [offer.shown?, offering.instance_variable_get(:@command_window).active], [false, true])
$player_ini = { "rejoin" => "w1" }
MGQ_Multiplayer::Player.define_singleton_method(:setting) { |key| $player_ini[key] }
MGQ_Multiplayer::Player.define_singleton_method(:store) { |key, value| $player_ini[key] = value.to_s }
class Scene_Title; def scene_changing?; false; end; end
MGQ_MpWorldMods.on_title_update(offering)
check("so does an outdated game started again to enter a world, which it then no longer enters on its own",
      [$called, offer.shown?, MGQ_MpWorldMods.rejoining, $player_ini["rejoin"]], [nil, true, nil, ""])
offer.hide
$outdated = false
