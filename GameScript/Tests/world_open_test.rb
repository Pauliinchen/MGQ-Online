#----------------------------------------------------------------
#  world_open_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Checked that an outdated game enters no world
#                            - Followed the scripts to their new names, without mp_
#                            - Read the details from their panels
#                            - Expected a hidden world's id alone in the form that adds it
#      Paulinchen  2026-10-03: Loaded the scripts split off the ones under test, and ui.rbx
#      Paulinchen  2026-10-02: Checked the seats a world code tells
#                            - Created
#
#----------------------------------------------------------------

# Checks worlds without a password and featured worlds (world.rbx): the forms taking an empty
# password, the directory's flags for both, entering a world without a password without being
# asked, the featured worlds' place in the list, what the details say, and an outdated game kept out.

require_relative "support"

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
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; end
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
  def self.clean(text); text; end
  def self.path(name); name; end
  module Log; def self.write(_message); end; end
  module Player; def self.share; end; def self.name; "Me"; end; end
  module Ini; def self.read(_path); {}; end; end
  module Link
    Function = Struct.new(:name, :signature) do
      def call(*args); $calls << [name, signature, args]; 1; end
    end
    def self.function(name, signature); Function.new(name, signature); end
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

scene = new_scene
scene.instance_variable_set(:@entry, entries[2])
scene.on_enter
check("a world with a password asks for it", $called, Scene_MpText)

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

# An outdated game.
$outdated = true
$calls.clear
check("an outdated game enters no world", [MGQ_MpWorld.start(MGQ_MpWorld::World.new("abcdef012345", {}), new_scene), MGQ_MpWorld.open?, $calls], ["Update.", false, []])
title = Window_TitleCommand.new
title.instance_variable_set(:@list, [{ :symbol => :continue }])
MGQ_MpWorld.add_title_command(title)
check("and finds the title command greyed out", title.instance_variable_get(:@list)[1].values_at(:symbol, :enabled), [:mgq_mp_world, false])
$outdated = false
