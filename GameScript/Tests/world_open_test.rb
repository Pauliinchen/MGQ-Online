#----------------------------------------------------------------
#  world_open_test.rb
#
#  Changelog:
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

# Checks worlds without a password and featured worlds (world.rbx): the forms taking an empty
# password, the directory's flags for both, entering a world without a password without being
# asked, the featured worlds' place in the list, what the details say, and an outdated game kept out
# and told so.

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
      def call(*args); check_dll_call(name, signature, args); $calls << [name, signature, args]; 1; end
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

# What typing in place needs.
module MGQ_Multiplayer
  module Background; def self.running?; true; end; end
  module Key; def self.pressed?(_code); false; end; end
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

# An outdated game.
$outdated = true
$calls.clear
check("an outdated game enters no world", [MGQ_MpWorld.start(MGQ_MpWorld::World.new("abcdef012345", {}), new_scene), MGQ_MpWorld.open?, $calls], ["Update.", false, []])
title = Window_TitleCommand.new
title.instance_variable_set(:@list, [{ :symbol => :continue }])
MGQ_MpWorld.add_title_command(title)
check("and finds the title command greyed out", title.instance_variable_get(:@list)[1].values_at(:symbol, :enabled), [:mgq_mp_world, false])

# The update notice, a message box that draws on nothing.
class Sprite_MpMessageBox
  attr_accessor :visible
  attr_reader :shown
  def initialize; end
  def show(*args); @shown = args; @visible = true; end
  def dispose; end
end
title_scene = Scene_Title.new
SceneManager.define_singleton_method(:scene) { title_scene }
notice = MGQ_MpWorld::UpdateNotice
check("the update notice shows on the title screen and holds the buttons", [notice.refresh, notice.instance_variable_get(:@box).shown[0], $capture], [true, "Monster Girl Quest! Online 9.9.9 is out", :update_notice])
check("and stays while nothing is pressed", [notice.refresh, notice.instance_variable_get(:@box).visible], [false, true])
$pressed = :C
notice.refresh
$pressed = nil
check("confirm closes it and gives the buttons back", [notice.instance_variable_get(:@box).visible, $capture], [false, nil])
check("it stays closed on this title screen", notice.refresh, false)
notice.hide
check("and shows again on the next one", notice.refresh, true)
notice.hide
$outdated = false

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
