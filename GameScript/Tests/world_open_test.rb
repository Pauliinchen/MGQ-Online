#----------------------------------------------------------------
#  world_open_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Checks worlds without a password and featured worlds (mp_world.rbx): the forms taking an empty
# password, the directory's flags for both, entering a world without a password without being
# asked, the featured worlds' place in the list and what the details say.

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
module MGQ_Multiplayer
  def self.available?; true; end
  def self.outdated?; false; end
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

load_script "mp_save_distribution"
load_script "mp_world"

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
check("a hidden world without a password is joined with none", join.problem, nil)
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

# What the details say.
detail = Window_MpWorldDetail.allocate
lines = []
detail.define_singleton_method(:contents) { Struct.new(:clear).new(nil) }
detail.define_singleton_method(:contents_height) { 24 * 20 }
detail.define_singleton_method(:contents_width) { 300 }
detail.define_singleton_method(:line_height) { 24 }
detail.define_singleton_method(:change_color) { |*| }
detail.define_singleton_method(:draw_text) { |*args| lines << args[4] }
%w[system_color normal_color power_up_color].each { |name| detail.define_singleton_method(name) { name } }
detail.show(entries[1], "me")
check("a featured world says so below its name", lines[0, 2], ["Golden", "Featured: one of the relay's own worlds."])
check("a world without a password says anyone may enter", lines.include?("No password: anyone may enter."), true)
check("made by the admin tool's player", lines.include?("Made by Global"), true)
