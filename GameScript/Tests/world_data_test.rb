#----------------------------------------------------------------
#  world_data_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-04: Checked picking the worlds or the commands as a whole before moving into them, and a long word broken inside it
#                            - Created
#
#----------------------------------------------------------------

# Checks what a creator tells about a world and which games may enter it (world.rbx,
# world_screen.rbx): the fingerprint of a game's data, the form's description, mods and rule,
# the directory's fields for them, a differing game kept out or asked first, and what the details
# say.

require "zlib"
require "fileutils"
require "tmpdir"

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
module Input; def self.trigger?(button); ($buttons || []).include?(button); end; end
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


load_script "world_save_distribution"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_text"
load_script "world_screen"

# A small window of the world screen: keeps the commands it opened with and whether it takes input.
class FakeChoice
  # The commands it opened with last, nil while closed.
  attr_reader :choices

  # Opens with commands and takes input.
  #
  # @param choices [Array<Array>] The commands.
  def start(choices); @choices = choices; end

  # Closes.
  def finish; @choices = nil; end

  # Takes input.
  def activate; end

  # Takes no input.
  def deactivate; end

  # The cursor's row.
  #
  # @return [Integer] -1, no cursor.
  def index; -1; end
end

# The lines at the top of the world screen: keeps what they show.
class FakeInfo
  # What they show.
  attr_reader :lines

  # Shows lines.
  #
  # @param lines [Array<String, nil>] The lines.
  def show(lines); @lines = lines; end
end

# Builds the world screen without its windows.
#
# @return [Scene_MpWorlds] The screen.
def new_scene
  scene = Scene_MpWorlds.allocate
  [:@actions_window, :@members_window, :@confirm_window, :@start_window, :@list_window, :@form_window].each { |name| scene.instance_variable_set(name, FakeChoice.new) }
  scene.instance_variable_set(:@info_window, FakeInfo.new)
  scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::Form.create })
  scene
end

# What the lines at the top of the world screen say, the player's name left out.
#
# @param scene [Scene_MpWorlds] The world screen.
# @return [String] The message.
def said(scene)
  scene.instance_variable_get(:@info_window).lines[1]
end

# An entry of the game's database.
Named = Struct.new(:name)

# A troop of the game's database.
Troop = Struct.new(:members)

# A common event of the game's database.
Common = Struct.new(:list)

# The game's map lists: the main one and one per further map folder.
class MapInfos
  # Creates the lists.
  #
  # @param lists [Array<Hash>] The maps of each folder, by id.
  def initialize(lists); @data = lists; end
end

# Sets up a small database, which the fingerprint is read from anew.
#
# @param skills [Array<String>] The skills' names, an empty one for an unused place.
# @param maps [Array<Integer>] The main folder's maps' ids.
# @param more_maps [Array<Integer>] The second folder's maps' ids.
def game_data(skills, maps, more_maps = [1])
  entries = lambda { |names| [nil] + names.map { |name| Named.new(name) } }
  $data_actors = entries.call(%w[Luka Alice])
  $data_classes = entries.call(%w[Hero])
  $data_skills = entries.call(skills)
  $data_items = entries.call(%w[Herb])
  $data_weapons = entries.call(%w[Sword])
  $data_armors = entries.call(%w[Shirt])
  $data_enemies = entries.call(%w[Slime])
  $data_states = entries.call(%w[Death])
  $data_troops = [nil, Troop.new([1]), Troop.new([])]
  $data_common_events = [nil, Common.new([1, 2]), Common.new([0])]
  lists = [maps, more_maps].map { |ids| Hash[ids.map { |id| [id, true] }] }
  $data_mapinfos = MapInfos.new(lists)
  MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
end

# The fingerprint.
game_data(["Slash", "", "Fire"], [2, 1])
plain = MGQ_MpWorld::GameData.fingerprint
check("the fingerprint names its format and a checksum per part", plain =~ /\A1:[0-9a-f]{8}(\.[0-9a-f]{8}){10}\z/ ? true : false, true)
check("a game matches itself", MGQ_MpWorld::GameData.differing(plain), [])
game_data(["Schlag", "", "Feuer"], [1, 2])
check("a translated game matches the untranslated one", MGQ_MpWorld::GameData.differing(plain), [])
game_data(["Slash", "Mod Skill", "Fire"], [1, 2, 488])
check("a mod's new skill and map are told apart, by name", MGQ_MpWorld::GameData.differing(plain), ["skills", "maps"])
game_data(["Slash", "", "Fire"], [1, 2], [1, 5])
check("so is a map in a further map folder", MGQ_MpWorld::GameData.differing(plain), ["maps"])
check("whose maps count on from a thousand", MGQ_MpWorld::GameData.map_ids, [1, 2, 1001, 1005])
game_data(["Slash", "Mod Skill", "Fire"], [1, 2, 488])
check("a world without game data is not compared", [MGQ_MpWorld::GameData.differing(""), MGQ_MpWorld::GameData.differing(nil)], [nil, nil])
check("nor one of another format", MGQ_MpWorld::GameData.differing(plain.sub("1:", "2:")), nil)
check("nor a damaged one", MGQ_MpWorld::GameData.differing("1:abc"), nil)
check("or past as many as asked", MGQ_MpWorld::GameData.text(%w[actors classes skills items], 2), "actors, classes and 2 more")
check("many parts are counted past the first four", MGQ_MpWorld::GameData.text(%w[actors classes skills items weapons armors]), "actors, classes, skills, items and 2 more")
check("few are all named", MGQ_MpWorld::GameData.text(%w[skills maps]), "skills, maps")
modded = MGQ_MpWorld::GameData.fingerprint

# The form.
form = MGQ_MpWorld::Form.create
form[:name] = "Modded Run"
check("a new world needs no description, no mods, and lets differing games in", [form.problem, form[:description], form[:mods], form[:mismatch]], [nil, "", "", true])
description = form.fields.find { |field| field.key == :description }
check("the description is a box of several lines in a panel of its own", [description.kind, description.lines, description.group, description.max_chars], [:area, 4, "Description", MGQ_MpWorld::MAX_DESCRIPTION_CHARS])
check("the mods and the mismatch checkbox share the Game data panel", [:mods, :mismatch].map { |key| field = form.fields.find { |candidate| candidate.key == key }; [field.kind, field.label, field.group] }, [[:text, "Mods", "Game data"], [:check, "Allow data mismatch", "Game data"]])
check("the starting point has its own panel", form.fields.select { |field| field.group == "Starting point" }.map { |field| field.label }, ["Shared save", "Player's choice", "Save"])
check("a description is tidied", form.check(description, "  A slow run.  "), ["A slow run.", nil])
check("and may be empty", form.check(description, "  "), ["", nil])
check("while a name may not", form.check(form.fields[0], " ")[1], "The name cannot be empty.")

# A game whose data cannot be read.
known_maps = $data_mapinfos
$data_mapinfos = nil
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
scene = new_scene
strict_form = scene.instance_variable_get(:@forms)[:new_world]
strict_form[:name] = "W"
strict_form[:mismatch] = false
scene.instance_variable_set(:@form_symbol, :new_world)
$calls.clear
scene.create_world
check("a world that keeps differing games out is not made while the creator's game data cannot be read", [$calls, said(scene) =~ /could not be read/ ? true : false], [[], true])
strict_form[:mismatch] = true
scene.create_world
check("a world for every game is", [$calls.last[0], $calls.last[2][9]], ["mp_dir_create", 0])
$data_mapinfos = known_maps
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
scene = new_scene
strict_form = scene.instance_variable_get(:@forms)[:new_world]
strict_form[:name] = "W"
strict_form[:mismatch] = false
scene.create_world
check("with the data read, an unticked Allow data mismatch makes a world for the same data only", [$calls.last[2][8], $calls.last[2][9]], ["#{modded}\0", 1])

# The directory.
MGQ_MpWorld::Directory.create("W", "p", 4, false, false, "", :description => "A slow run.", :mods => "Some Mod", :data => modded, :strict => true)
check("create hands the description, the mods, the game data and the rule to the DLL", [$calls.last[1], $calls.last[2][6..9]], ["pplllppppl", ["A slow run.\0", "Some Mod\0", "#{modded}\0", 1]])
MGQ_MpWorld::Directory.create("W", "p", 4, false, false, "")
check("or nothing", $calls.last[2][6..9], ["\0", "\0", "\0", 0])
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tw1\t4\t0\tc\t0\tC\tStrict\tnone\t0\t0\t1\t0\t1\t#{plain}\tNo mods\tUnmodded only.\n" \
  "world\tw2\t4\t0\tc\t0\tC\tLoose\tnone\t0\t0\t1\t0\t0\t#{plain}\tSome Mod\tA slow run through part one of the story with friends.\n" \
  "world\tw3\t4\t0\tc\t0\tC\tSame\tnone\t0\t0\t1\t0\t1\t#{modded}\t\t\n" \
  "world\tw4\t4\t0\tc\t0\tC\tOld\tnone\t0\t0\t1\t0\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads which worlds take the same data only", listed.map { |world| world.strict }, [true, false, true, false])
check("their creators' game data", listed.map { |world| world.data }, [plain, plain, modded, ""])
check("the mods they need and their descriptions", [listed[1].mods, listed[0].description, listed[3].mods, listed[3].description], ["Some Mod", "Unmodded only.", "", ""])
MGQ_MpWorld::Favourites.define_singleton_method(:all) { [] }
MGQ_MpWorld::World.define_singleton_method(:all) { [] }
entries = MGQ_MpWorld.entries(listed, true).sort_by { |entry| entry.id }
check("an entry tells what differs", entries.map { |entry| entry.differing }, [["skills", "maps"], ["skills", "maps"], [], nil])

# Entering.
scene = new_scene
scene.instance_variable_set(:@entry, entries[0])
$calls.clear
$sounds.clear
scene.on_enter
check("a game that differs is kept out of a world for the same data", [$calls, $sounds, scene.instance_variable_get(:@busy)], [[], ["buzzer"], nil])
check("and told what the world needs", said(scene), "Strict only takes matching game data. It needs: No mods.")

scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
$calls.clear
scene.on_enter
confirming = scene.instance_variable_get(:@confirm_window)
check("in another world it is asked first", [$calls, confirming.choices.map { |choice| choice[1] }], [[], [:yes, :cancel]])
check("with what the world needs", said(scene), "Your game data differs. It needs: Some Mod. Enter anyway?")
scene.on_confirmed
check("and enters once the player says so", [$calls.last[0], $calls.last[2], scene.instance_variable_get(:@busy)], ["mp_dir_unlock", ["w2\0", "\0"], "unlock"])
$calls.clear
scene.instance_variable_set(:@busy, nil)
scene.on_enter
check("the next time it is asked again", [$calls, confirming.choices.nil?], [[], false])

[entries[2], entries[3]].each do |entry|
  scene = new_scene
  scene.instance_variable_set(:@entry, entry)
  $calls.clear
  scene.on_enter
  check("#{entry.name}: a game that matches, or a world that does not tell, is entered at once", [$calls.last[0], scene.instance_variable_get(:@confirm_window).choices], ["mp_dir_unlock", nil])
end

# Adding a hidden world by its id.
added = []
MGQ_MpWorld::Added.define_singleton_method(:all) { added }
MGQ_MpWorld::Added.define_singleton_method(:add) { |id| added << id }
MGQ_MpWorld::Added.define_singleton_method(:remove) { |id| added.delete(id) }
scene = new_scene
scene.instance_variable_get(:@forms)[:join_hidden] = MGQ_MpWorld::Form.join
scene.instance_variable_get(:@forms)[:join_hidden][:id] = "ab" * 16
scene.instance_variable_set(:@form_symbol, :join_hidden)
form_window = scene.instance_variable_get(:@form_window)
form_window.define_singleton_method(:unselect) { }
form_window.define_singleton_method(:select) { |_index| }
$calls.clear
scene.send_form
check("the form looks the world up by its id", [$calls.last[0], $calls.last[2], scene.instance_variable_get(:@busy)], ["mp_dir_find", ["#{'ab' * 16}\0"], "find"])
$dll["mp_dir_action"] = "state=done\nkind=find\nname=Hidden Base\n\n"
$calls.clear
scene.follow_action
check("a world that exists is added to the list, not entered", [added, said(scene), scene.form, $calls.map { |call| call[0] }.include?("mp_dir_unlock")], [["ab" * 16], "Hidden Base was added to your list.", nil, false])
check("the list is then asked for it too", $calls.map { |call| [call[0], call[2]] }.select { |call| %w[mp_dir_watch mp_dir_refresh].include?(call[0]) }, [["mp_dir_watch", ["#{'ab' * 16}\0"]], ["mp_dir_refresh", []]])
check("and the form is empty again", scene.instance_variable_get(:@forms)[:join_hidden][:id], "")
scene = new_scene
scene.instance_variable_get(:@forms)[:join_hidden] = MGQ_MpWorld::Form.join
scene.instance_variable_get(:@forms)[:join_hidden][:id] = "cd" * 16
scene.instance_variable_set(:@form_symbol, :join_hidden)
scene.send_form
$dll["mp_dir_action"] = "state=failed\nkind=find\nerror=There is no such world.\n\n"
scene.follow_action
check("a world that does not exist is not added", [added, said(scene)], [["ab" * 16], "There is no such world."])

# Taking an added world off the list again.
hidden_entry = MGQ_MpWorld::Entry.new("ab" * 16, "Hidden Base", listed[0], nil, false, false)
actions = lambda do |entry|
  screen = new_scene
  screen.instance_variable_get(:@list_window).define_singleton_method(:current_ext) { entry }
  screen.on_world
  [screen, screen.instance_variable_get(:@actions_window).choices.map { |choice| choice[1] }]
end
scene, offered_actions = actions.call(hidden_entry)
check("an added world never entered may be removed from the list", offered_actions.include?(:forget), true)
check("another world may not", actions.call(entries[1])[1].include?(:forget), false)
scene.on_forget
check("removing it forgets its id", [added, said(scene)], [[], "Hidden Base was removed from your list."])

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
check("the details come in panels: the world, its game data, its players", panels.map { |panel| panel.title }, ["World", "Game data", "Players"])
check("the mods a world needs", cell_of(panels, "Mods").text, "Some Mod")
check("a game that differs is told in what, in the warning color", [cell_of(panels, "Your game").text, cell_of(panels, "Your game").color], ["Differs: skills, maps", :warn])
check("a world for every game warns those that differ", panels[1].note, "differing games are warned")
panels = detail.panels(entries[2], "me")
check("a game that matches is told so, and the world's rule", [cell_of(panels, "Your game").text, cell_of(panels, "Your game").color, panels[1].note], ["Matches the creator's", :good, "same data only"])
check("a world that names no mod says so", cell_of(panels, "Mods").text, "No mod named")
panels = detail.panels(entries[3], "me")
check("a world that does not tell is not compared", [cell_of(panels, "Your game").text, panels[1].note], ["Not compared: the world does not tell", nil])

# The players.
member = MGQ_MpWorld::Directory::Member
crowd = listed[0].dup
crowd.members = [member.new("me", true, "Me"), member.new("a", true, "Ann"), member.new("b", false, "Bo"), member.new("c", false, "Cy"), member.new("d", false, "Di")]
players = detail.players_panel(crowd, "me")
check("the players come two to a row, the player marked, the rest counted", players.rows.map { |row| row.map { |cell| cell && cell.text } }, [["Me (you)", "Ann"], ["Bo", "and 2 more"]])
check("those online in the color of what is fine", players.rows.flatten.map { |cell| cell.color }, [:good, :good, :normal, :normal])
check("with how many joined beside the heading", players.note, "5 joined")
crowd.members = crowd.members.first(3)
check("an odd one leaves its neighbour's place empty", detail.players_panel(crowd, "me").rows.last, [Window_MpWorldDetail::Cell.new(nil, "Bo", :normal), nil])

# The description.
detail.show(entries[1], "me")
start = texts.index("DESCRIPTION")
check("the description comes last, on as many lines as it needs", texts[start + 1..-1], ["A slow run through part one of the story with", "friends."])
check("a long one is cut where the panel ends", detail.description_lines("one two three four five six", 80, 2), ["one", "two .."])
check("a long value is cut at its end", detail.cut("Differs: actors, classes and 9 more", 200), "Differs: actor..")

# Where the form's fields are drawn.
window = Window_MpWorldForm.allocate
window.define_singleton_method(:contents_width) { 386 }
groups = []
rects = window.places(form.fields) { |group, y, height| groups << [group, y, height] }
key = lambda { |name| rects[form.fields.index { |field| field.key == name }] }
check("every field has a place, and the form fits its window", [rects.compact.size, rects.map { |rect| rect.y + rect.height }.max <= 360], [form.fields.size, true])
check("the panels come in the form's order, one below the other", [groups.map { |group| group[0] }, groups.each_cons(2).all? { |upper, lower| upper[1] + upper[2] < lower[1] }], [["World", "Starting point", "Game data", "Description"], true])
check("two fields of a row share it without touching", [key.call(:password).y == key.call(:seats).y, key.call(:password).x + key.call(:password).width < key.call(:seats).x], [true, true])
check("the description takes four lines across its panel", [key.call(:description).height, key.call(:description).width], [4 * 16 + 2, 380])
check("the button comes below the last panel, across the window", [key.call(:confirm).y > groups.last[1] + groups.last[2], key.call(:confirm).width], [true, 386])
check("no two fields overlap", rects.combination(2).none? { |a, b| a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height }, true)
join_rects = window.places(MGQ_MpWorld::Form.join.fields) { |*| }
check("the join form places its fields the same way", join_rects.map { |rect| rect.y }, join_rects.map { |rect| rect.y }.sort.uniq)

# The editor every text box shares.
$held = []
$key_down = nil
module MGQ_Multiplayer
  module Capture; def self.repeat?(button); $held.include?(button); end; end
  module Key; def self.pressed?(code); $key_down == code; end; end
end
editor = MGQ_MpUi::TextEdit.new("hello", :max_chars => 8, :allowed => /\A[a-z ]\z/)
check("the editor starts with the cursor at the end of its text", [editor.text, editor.cursor, editor.cursor_shown?], ["hello", 5, true])
check("typing goes in at the cursor", [editor.type("x"), editor.text, editor.cursor], [:edited, "hellox", 6])
$held = [:LEFT]
3.times { editor.update_keys }
$held = []
check("left moves the cursor", editor.cursor, 3)
editor.type("y")
check("where the next character goes in", [editor.text, editor.cursor], ["helylox", 4])
check("backspace removes the character before the cursor", [editor.type("\b"), editor.text, editor.cursor], [:edited, "hellox", 3])
$key_down = 0x2E
editor.update_keys
check("delete the one after it", [editor.text, editor.cursor], ["helox", 3])
$key_down = 0x24
editor.update_keys
check("home goes to the start, where backspace does nothing", [editor.cursor, editor.type("\b"), editor.text], [0, nil, "helox"])
$key_down = 0x23
check("end goes to the end, and the editor says it moved", [editor.update_keys, editor.cursor], [true, 5])
$key_down = nil
check("a frame without keys changes nothing", editor.update_keys, false)
check("a character the box does not take is refused", [editor.type("7"), editor.text], [:refused, "helox"])
3.times { editor.type("a") }
check("as is one past the longest text", [editor.type("a"), editor.text.size], [:refused, 8])
check("enter and escape are left to the box's owner", [editor.type("\r"), editor.type("\e"), editor.text.size], [:enter, :escape, 8])
MGQ_MpUi::TextEdit::BLINK_FRAMES.times { editor.update_keys }
check("the cursor blinks, and shows again once it moves", [editor.cursor_shown?, (editor.move_to(2); editor.cursor_shown?)], [false, true])
measure = Object.new
measure.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * 10) }
long = MGQ_MpUi::TextEdit.new("abcdefghijklmnopqrst")
check("a box of one line shows the end of a long text while the cursor is there", long.visible(measure, 80), ["mnopqrst", 8])
long.move_to(14)
check("it stays put while the cursor moves inside what it shows", long.visible(measure, 80), ["mnopqrst", 2])
long.move_to(5)
check("and moves back once the cursor leaves it at the left", long.visible(measure, 80), ["fghijklm", 0])
check("a password shows as many stars", MGQ_MpUi::TextEdit.new("abc").visible(measure, 80, "***"), ["***", 3])

# Lines that keep each character's place.
widths = lambda { |part| part.size * 10 }
check("a text is broken before the word that does not fit, its spaces kept", MGQ_MpUi.wrap_spans("one two  three four", 100, &widths), [[0, 9], [9, 10]])
check("an empty text is one empty line", MGQ_MpUi.wrap_spans("", 100, &widths), [[0, 0]])
check("a word longer than a line is broken inside it", MGQ_MpUi.wrap_spans("a verylongwordindeed b", 100, &widths), [[0, 2], [2, 10], [12, 10]])
spans = MGQ_MpUi.wrap_spans("one two three four", 80, &widths)
check("a place in the text is on the line that starts at or before it", [spans, [0, 7, 8, 13, 18].map { |place| MGQ_MpUi.span_of(spans, place) }], [[[0, 8], [8, 6], [14, 4]], [0, 0, 1, 1, 2]])

# The description as it is typed.
drawn = []
cursors = []
font = Struct.new(:size, :color).new(18, "normal_color")
canvas = Struct.new(:font).new(font)
canvas.define_singleton_method(:fill_rect) { |*args| cursors << args[0, 2] if args[2] == MGQ_MpUi::TextBox::CURSOR_WIDTH }
canvas.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * 9) }
canvas.define_singleton_method(:draw_text) { |*args| drawn << args[4] }
window.define_singleton_method(:contents) { canvas }
window.define_singleton_method(:change_color) { |*| }
window.define_singleton_method(:normal_color) { "normal_color" }
window.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * 9) }
window.define_singleton_method(:draw_text) { |*args| drawn << args[4] }
window.define_singleton_method(:index) { form.fields.index(description) }
window.instance_variable_set(:@form, form)
window.instance_variable_set(:@widths, {})
window.instance_variable_set(:@rects, rects)
form[:description] = ""
window.draw_area(key.call(:description), description)
check("an empty description says what it is for", drawn, ["What the world is about"])
drawn.clear
form[:description] = "A slow run through part one of the story with friends, with every side quest on the way."
form.editing = :description
form.edit = MGQ_MpUi::TextEdit.new(form[:description])
window.draw_area(key.call(:description), description)
check("a typed one shows whole, on several lines", drawn.map { |line| line.rstrip }, ["A slow run through part one of the story", "with friends, with every side quest on", "the way."])
area = key.call(:description)
check("with the cursor at its end, on the last line", cursors, [[area.x + 4 + 8 * 9, area.y + 1 + 2 * 16 + 2]])
lines = window.current_area_spans(form[:description])
last = form.edit.cursor
form.edit.move_line(lines, 1)
check("down from the last line leaves the cursor there", form.edit.cursor, last)
form.edit.move_line(lines, -1)
check("up moves the cursor a line up, as far into it", [form.edit.cursor, form[:description][41 + 8, 4]], [41 + 8, "ends"])
form.edit.move_to(3)
$held = [:DOWN]
check("the down arrow goes from a short way into a line as far into the next", [form.edit.update_keys(lines), form.edit.cursor], [true, 41 + 3])
$held = []
drawn.clear
form[:description] = (%w[word] * 40).join(" ")
form.edit = MGQ_MpUi::TextEdit.new(form[:description])
window.draw_area(key.call(:description), description)
check("one longer than the box shows the lines around the cursor while it is typed", [drawn.size, drawn.last.rstrip], [4, "word word word word word word word word"])
form.edit.move_to(0)
drawn.clear
window.draw_area(key.call(:description), description)
check("and follows the cursor back to its start", [drawn.size, drawn.first[0, 9], form.edit.first_line(window.current_area_spans(form[:description]), 4)], [4, "word word", 0])
form.editing = nil
form.edit = nil
drawn.clear
window.draw_area(key.call(:description), description)
check("and its first lines, cut, once it is not", [drawn.size, drawn.first[0, 9], drawn.last[-2, 2]], [4, "word word", ".."])

# A text box of one line as it is typed.
drawn.clear
cursors.clear
window.define_singleton_method(:system_color) { "system_color" }
form[:mods] = "Some Mod; !Another Mod; ?A Third Mod With A Long Name"
mods_field = form.fields.find { |field| field.key == :mods }
window.draw_box(key.call(:mods), mods_field, true)
check("a text too long for its box is cut at its end while nobody types", drawn.last[-2, 2], "..")
form.editing = :mods
form.edit = MGQ_MpUi::TextEdit.new(form[:mods])
drawn.clear
window.draw_box(key.call(:mods), mods_field, true)
check("while typed into, the box shows the text around the cursor, and the cursor after it", [form[:mods].end_with?(drawn.last), cursors.size], [true, 1])
form.editing = nil
form.edit = nil
check("a description may be 1000 characters long", MGQ_MpWorld::MAX_DESCRIPTION_CHARS, 1000)

# The hints, which share two lines at the top of the world screen.
long = (MGQ_MpWorld::Form.create.fields + MGQ_MpWorld::Form.join.fields).select { |field| field.hint.size > 100 }
check("every field's hint fits two lines", long.map { |field| field.key }, [])

# Changing a world.
edit = MGQ_MpWorld::Form.edit(listed[1])
check("the edit form holds what may change, filled in as the world is", [edit.title, edit.fields.map { |field| field.key }, edit[:seats], edit[:mods], edit[:description]], ["Edit Loose", [:seats, :mods, :description, :confirm], "4", "Some Mod", "A slow run through part one of the story with friends."])
check("and may be sent as it is", edit.problem, nil)
offered = lambda do |me, admin|
  scene = new_scene
  scene.instance_variable_set(:@me, me)
  scene.instance_variable_set(:@admin, admin)
  list = scene.instance_variable_get(:@list_window)
  list.define_singleton_method(:current_ext) { entries[1] }
  scene.on_world
  scene.instance_variable_get(:@actions_window).choices.map { |choice| choice[1] }.include?(:edit_world)
end
check("the creator and an admin are offered to edit a world, another player is not", [offered.call("c", false), offered.call("me", true), offered.call("me", false)], [true, true, false])
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
form_window = scene.instance_variable_get(:@form_window)
form_window.define_singleton_method(:form=) { |form| @form = form }
form_window.define_singleton_method(:select) { |index| @index = index }
form_window.define_singleton_method(:unselect) { @index = -1 }
scene.on_edit_world
check("editing opens the form in place of the details", [scene.form.title, scene.instance_variable_get(:@form_symbol)], ["Edit Loose", :edit_world])
scene.form[:seats] = "8"
scene.form[:mods] = ""
$calls.clear
scene.send_form
check("sending it hands the changes to the DLL", [$calls.last[0], $calls.last[1], $calls.last[2], scene.instance_variable_get(:@busy)], ["mp_dir_edit", "plpp", ["w2\0", 8, "A slow run through part one of the story with friends.\0", "\0"], "edit"])
$dll["mp_dir_action"] = "state=done\nkind=edit\n\n"
scene.follow_action
check("once changed, the form closes and the screen says so", [scene.form, said(scene)], [nil, "Loose was changed."])
scene.on_edit_world
scene.form[:seats] = "99"
$calls.clear
scene.send_form
check("seats out of range are refused before anything is sent", [$calls, said(scene)], [[], "Max Players must be a number from 2 to 32."])

# The seats a world's code tells follow the directory.
world = MGQ_MpWorld::World.new("abcdef012345", "code" => "mgqmp2;abcdefghjkmnpqrs;r1;4")
world.describe("Loose", "w2", 8)
check("a world's code takes the seats the directory lists", [world.seats, world.code], [8, "mgqmp2;abcdefghjkmnpqrs;r1;8"])
old = MGQ_MpWorld::World.new("abcdef012345", "code" => "mgqmp2;abcdefghjkmnpqrs;r1")
old.describe("Old", "w4", 8)
check("a code without seats stays as it is", old.code, "mgqmp2;abcdefghjkmnpqrs;r1")

# The players and the mods of a world, listed from its choices.
check("mods are split at each semicolon", MGQ_MpWorld.mods_of(" Mod A ;Mod B;; "), ["Mod A", "Mod B"])
check("no mods give none", [MGQ_MpWorld.mods_of(""), MGQ_MpWorld.mods_of(nil)], [[], []])
check("a mod written with an exclamation mark is required, one with a question mark essential, both named first without their mark", [MGQ_MpWorld.mods_of("Mod A; ?Mod D; !Mod B;! Mod C; !; ?"), MGQ_MpWorld.required_mods("Mod A; ?Mod D; !Mod B;! Mod C; !"), MGQ_MpWorld.essential_mods("Mod A; ?Mod D; !Mod B")], [["Mod B", "Mod C", "Mod D", "Mod A"], ["Mod B", "Mod C"], ["Mod D"]])
MGQ_MpWorld.instance_variable_set(:@installed, ["modb", "maskofenvy"])
check("a mod's script is found by its name, whatever its case, spaces or underscores", ["Mod B", "mod_b.rb", "Mask of Envy", "Mask-Of-Envy", "Mod C"].map { |mod| MGQ_MpWorld.installed_mod?(mod) }, [true, true, true, true, false])
check("only required mods are looked for", MGQ_MpWorld.missing_mods("Mod A; !Mod B; !Mod C; ?Mod E"), ["Mod C"])
essential_world = listed[1].dup
essential_world.mods = "Mod A; ?Mod E; !Mod B; !Mod C"
essential_entry = MGQ_MpWorld::Entry.new("w2", "Loose", essential_world, nil, false, false)
essential_cell = cell_of(detail.panels(essential_entry, "me"), "Mods")
check("the details show required mods first, fine when installed and wrong when missing, then essential ones in gold", [essential_cell.chips, essential_cell.chip_colors], [["Mod B", "Mod C", "Mod E", "Mod A"], { "Mod B" => :good, "Mod C" => :bad, "Mod E" => :gold }])
matching = listed[2].dup
matching.mods = "?Mod E; !Mod B"
matching_entry = MGQ_MpWorld::Entry.new("w3", "Same", matching, nil, false, false)
check("an essential mod is fine while this game's data matches the world's", [matching_entry.differing, cell_of(detail.panels(matching_entry, "me"), "Mods").chip_colors], [[], { "Mod B" => :good, "Mod E" => :good }])
check("the list box says so, or that the data differs", [new_scene.mod_lines("?Mod E", []), new_scene.mod_lines("?Mod E", ["skills"])], [[[:head, "Mods (1)"], [:item, "Mod E", :good, "essential, data matches"]], [[:head, "Mods (1)"], [:item, "Mod E", :gold, "essential, data differs"]]])
check("the list box says which are installed and which nothing checks", new_scene.mod_lines("Mod A; ?Mod E; !Mod B; !Mod C"), [[:head, "Mods (4)"], [:item, "Mod B", :good, "required, installed"], [:item, "Mod C", :bad, "required, missing"], [:item, "Mod E", :gold, "essential, not checked"], [:item, "Mod A", :plain, nil]])
scene = new_scene
scene.instance_variable_set(:@entry, essential_entry)
$calls.clear
$sounds.clear
scene.on_enter
check("a game that lacks a required mod is kept out and told which", [$calls, $sounds, said(scene)], [[], ["buzzer"], "Loose needs Mod C: no such script in your Patch folder."])
essential_world.mods = "Mod A; !Mod B; ?Mod E"
scene = new_scene
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w2", "Loose", essential_world, nil, false, false))
scene.on_enter
check("one that has them all goes on, to the game data check, whatever essential mods the world names", scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }, [:yes, :cancel])
Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch", "Sub"))
  File.write(File.join(folder, "Patch", "Mask_of_Envy.rb"), "")
  File.write(File.join(folder, "Patch", "Sub", "Deep Mod.rb"), "")
  Dir.chdir(folder) do
    MGQ_MpWorld.instance_variable_set(:@installed, nil)
    check("the Patch folder is read with its folders", ["Mask of Envy", "deep_mod", "Other"].map { |mod| MGQ_MpWorld.installed_mod?(mod) }, [true, true, false])
  end
end
MGQ_MpWorld.instance_variable_set(:@installed, ["modb"])
modded_world = listed[1].dup
modded_world.mods = "Mod A; Mod B"
modded_world.members = [member.new("me", true, "Me"), member.new("a", false, "Ann")]
modded_entry = MGQ_MpWorld::Entry.new("w2", "Loose", modded_world, nil, false, false)
scene = new_scene
scene.instance_variable_set(:@me, "me")
scene.instance_variable_get(:@list_window).define_singleton_method(:current_ext) { modded_entry }
scene.on_world
names = scene.instance_variable_get(:@actions_window).choices.map { |choice| choice[0] }
check("a world's choices leave its players and its mods to the details", names.grep(/Players|Mods/), [])
scene.open_box(:players)
box = scene.instance_variable_get(:@box)
check("the players open in the list box, under the world's name", [box.title, box.note], ["Loose", "Players"])
check("those online first, then the others, each under a heading, the player marked", box.lines, [[:head, "Online (1)"], [:item, "Me (you)", :good, "online"], [:head, "Offline (1)"], [:item, "Ann", :grey, "offline"]])
check("the first player is picked", box.selected, 1)
scene.open_box(:mods)
box = scene.instance_variable_get(:@box)
check("each mod is listed on its own", [box.note, box.lines], ["Mods", [[:head, "Mods (2)"], [:item, "Mod A", :plain, nil], [:item, "Mod B", :plain, nil]]])
check("the details name them with commas", cell_of(detail.panels(modded_entry, "me"), "Mods").text, "Mod A, Mod B")
mods_cell = cell_of(detail.panels(modded_entry, "me"), "Mods")
check("each mod gets a box of its own", mods_cell.chips, ["Mod A", "Mod B"])
detail.contents.font.size = 18
check("the boxes sit side by side, as wide as their texts", detail.chips(["Mod A", "Mod B"], 304), [["Mod A", 0, 57], ["Mod B", 61, 57]])
check("mods that do not fit are counted in a last box", detail.chips(["First Long Mod", "Second Long Mod", "Third Long Mod", "Fourth Long Mod"], 304).map { |chip| chip[0] }, ["First Long Mod", "+3 more"])
check("as many as fit are named", detail.chips(["A", "B", "C", "A Very Long Mod Name That Fills The Row"], 304).map { |chip| chip[0] }, ["A", "B", "C", "+1 more"])
tight = detail.chips(["A Very Long Mod Name That Fills The Whole Row", "B"], 304)
check("a first mod too long for the row is cut beside the count", [tight.map { |chip| chip[0] }, tight.last[1] + tight.last[2] <= 304], [["A Very Long Mod Name..", "+1 more"], true])
check("a world that names no mod shows the plain text", cell_of(detail.panels(entries[3], "me"), "Mods").chips, nil)

# The list box's pick.
long = Sprite_MpListBox::View.of("W", "Players", [[:head, "Online (20)"]] + (1..20).map { |n| [:item, "P#{n}", :good, "online"] })
check("the list box picks its first item and shows from the top", [long.selected, long.scroll, Sprite_MpListBox::LIST_ROWS], [1, 0, 14])
long.move(-1)
check("it stops at the first item", long.selected, 1)
16.times { long.move(1) }
check("moving down past the box scrolls the pick into sight", [long.selected, long.scroll], [17, 4])
long.move(99)
check("it stops at the last item", [long.selected, long.scroll], [20, 7])
20.times { long.move(-1) }
check("back at the top the heading is in sight again", [long.selected, long.scroll], [1, 0])
check("a point over a line finds it, outside the list none", [Sprite_MpListBox.line_at(100, 32 + 30 + 24 * 2 + 3, long), Sprite_MpListBox.line_at(100, 40, long), Sprite_MpListBox.line_at(10, 100, long)], [2, nil, nil])
check("a list without items picks none and does not move", (empty = Sprite_MpListBox::View.of("W", nil, [[:head, "None"]]); empty.move(1); empty.selected), nil)

# What the details open.
detail, = new_detail(386, 336)
detail.define_singleton_method(:x) { 230 }
detail.define_singleton_method(:y) { 96 }
detail.define_singleton_method(:standard_padding) { 12 }
detail.show(modded_entry, "me")
check("the details of a world with mods and a description open its mods, its players and its description", detail.targets, [:mods, :players, :description])
mods_rect = detail.instance_variable_get(:@targets)[:mods]
check("a click on the Mods row finds the mods", detail.target_at(230 + 12 + mods_rect.x + 5, 96 + 12 + mods_rect.y + 5), :mods)
players_rect = detail.instance_variable_get(:@targets)[:players]
check("one on the Players panel the players, one elsewhere nothing", [detail.target_at(230 + 12 + 5, 96 + 12 + players_rect.y + 5), detail.target_at(5, 5)], [:players, nil])
detail.show(entries[3], "me")
check("a world without mods opens only its players", detail.targets, [:players])
detail.show(gone, "me") if defined?(gone)

# The description in the list box.
detail.show(entries[1], "me")
check("a world with a description opens it too", detail.targets, [:mods, :players, :description])
scene = new_scene
scene.instance_variable_set(:@entry, entries[1])
measure = Struct.new(:font).new(Struct.new(:size).new(18))
measure.define_singleton_method(:text_size) { |text| Struct.new(:width).new(text.size * 20) }
scene.instance_variable_set(:@list_box, Struct.new(:bitmap).new(measure))
scene.open_box(:description)
box = scene.instance_variable_get(:@box)
check("the whole description opens in the list box, broken into lines", [box.note, box.lines.map { |line| line[1] }.join(" "), box.lines.size > 1], ["Description", "A slow run through part one of the story with friends.", true])

# The left side: the worlds above the commands.

# A window of the left side: keeps its rows, its cursor and whether it takes input.
class FakeList
  attr_accessor :index, :active, :boxed
  attr_reader :rows

  # Creates the window.
  #
  # @param rows [Array] Its rows, each [symbol, ext].
  def initialize(rows); @rows = rows; @index = 0; @active = true; end
  def item_max; @rows.size; end
  def select(index); @index = index; end
  def unselect; @index = -1; end
  def activate; @active = true; end
  def deactivate; @active = false; end
  def width; 230; end
  def height; 100; end
  def current_symbol; @index >= 0 && @rows[@index] ? @rows[@index][0] : nil; end
  def current_ext; @index >= 0 && @rows[@index] ? @rows[@index][1] : nil; end
  def select_symbol(symbol); @index = @rows.index { |row| row[0] == symbol }; end
  def entries=(entries); @rows = entries.map { |entry| [:world, entry] }; @index = [@index, @rows.size - 1].min if @index >= 0; end
  def set_handler(symbol, _method); (@handlers ||= []) << symbol; end
  def handlers; @handlers || []; end
end

worlds = FakeList.new([])
commands = FakeList.new([[:new_world, nil], [:join_hidden, nil], [:rename, nil], [:back, nil]])
pane = MpWorldListPane.new(worlds, commands)
left = 0
[:world, :new_world, :cancel].each { |symbol| pane.set_handler(symbol, symbol == :cancel ? lambda { left += 1 } : nil) }
check("each window takes its own choices, cancel backs out of both, and Back leaves the screen", [worlds.handlers, commands.handlers], [[:world, :cancel], [:new_world, :cancel, :back]])
check("the commands are picked as a whole, before any world arrived", [pane.inside?, pane.active, commands.boxed, worlds.boxed, pane.current_symbol, worlds.active, commands.active, commands.index], [false, true, true, false, nil, false, false, -1])
check("without worlds the list cannot be picked", [pane.pick(:worlds), commands.boxed], [false, true])
pane.entries = [:a, :b, :c]
check("the first worlds to arrive are picked", [worlds.boxed, commands.boxed, pane.current_ext, worlds.index], [true, false, nil, -1])
$buttons = [:DOWN]
pane.update
check("down picks the commands", [commands.boxed, worlds.boxed], [true, false])
$buttons = [:UP]
pane.update
check("up the worlds again", [worlds.boxed, commands.boxed], [true, false])
$buttons = [:C]
pane.update
check("confirm moves into the picked window, onto its first row", [pane.inside?, pane.current_symbol, pane.current_ext, worlds.active, worlds.boxed], [true, :world, :a, true, false])
worlds.select(2)
$buttons = [:B, :C, :DOWN]
pane.update
check("the pane leaves the keys to the window the cursor is in", [pane.current_ext, $buttons.size, left], [:c, 3, 0])
$buttons = []
worlds.deactivate
pane.back_out
check("cancel there moves back out, around the window", [pane.inside?, pane.active, worlds.boxed, worlds.index, worlds.active], [false, true, true, -1, false])
$buttons = [:B]
pane.update
check("the press that moved out does not also leave the screen", left, 0)
pane.settle
pane.update
check("the next one does", left, 1)
pane.pick(:commands)
pane.enter
commands.select(2)
commands.deactivate
pane.back_out
pane.pick(:worlds)
pane.enter
check("a window is entered on the row the cursor left in it", pane.current_ext, :c)
worlds.deactivate
pane.back_out
pane.pick(:commands)
pane.enter
check("the commands too", pane.current_symbol, :rename)
pane.deactivate
check("the pane takes no input while something else does", [pane.active, worlds.active, commands.active], [false, false, false])
pane.activate
check("and gives it back to the window with the cursor", [worlds.active, commands.active], [false, true])
commands.deactivate
pane.back_out
pane.pick(:worlds)
pane.deactivate
pane.activate
$buttons = [:C]
pane.update
check("a pick that takes the input again waits a frame for its keys", [pane.active, pane.inside?], [true, false])
$buttons = []
pane.settle
pane.enter
pane.entries = []
check("the commands are picked when the last world goes", [pane.inside?, commands.boxed, pane.active, pane.enter, pane.current_symbol], [false, true, true, true, :rename])
pane.entries = [:d]
check("worlds arriving later leave the cursor where it is", pane.current_symbol, :rename)
pane.select_symbol(:join_hidden)
check("a command is picked by its symbol", [pane.current_symbol, pane.inside?, worlds.index], [:join_hidden, true, -1])
check("the pane is as wide as the worlds and as high as both windows", [pane.width, pane.height], [230, 200])

# The creator updates a world's game data.
detail, = new_detail(386, 336)
check("the creator of a world whose data differs from their game may update it", [cell_of(detail.panels(entries[1], "c"), "Your game").target, detail.panels(entries[1], "c")[1].note], [:data, "confirm on Your game: update"])
check("another player may not", cell_of(detail.panels(entries[1], "me"), "Your game").target, nil)
check("nor the creator while their game matches", cell_of(detail.panels(entries[2], "c"), "Your game").target, nil)
check("the creator of a world that tells no data may set theirs", [cell_of(detail.panels(entries[3], "c"), "Your game").target, cell_of(detail.panels(entries[3], "c"), "Your game").text], [:data, "Not compared. Confirm to set yours"])
detail.show(entries[1], "c")
check("the row is one of what the details open, below the mods", detail.targets, [:mods, :data, :players, :description])
scene = new_scene
scene.instance_variable_set(:@me, "c")
scene.instance_variable_get(:@list_window).define_singleton_method(:current_ext) { entries[1] }
scene.open_target(:data)
check("confirming on it asks first", [scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }, said(scene)], [[:yes, :cancel], "Take your game's data as that of Loose? Games that differ from yours are then warned or kept out."])
$calls.clear
scene.on_confirmed
check("then hands this game's data to the DLL", [$calls.last[0], $calls.last[2], scene.instance_variable_get(:@busy)], ["mp_dir_set_data", ["w2\0", "#{MGQ_MpWorld::GameData.fingerprint}\0"], "data"])
$dll["mp_dir_action"] = "state=done\nkind=data\n\n"
scene.follow_action
check("and says so once it is done", said(scene), "The data scan of Loose was updated to your game.")
scene = new_scene
scene.instance_variable_set(:@me, "c")
scene.instance_variable_set(:@entry, entries[0])
scene.on_enter
check("the creator of a world for the same data whose game differs is told where to update it", said(scene), "Strict only takes matching game data. Update it under Your game in its details.")

# The edit form of a world's creator.
own_edit = MGQ_MpWorld::Form.edit(listed[1], true)
check("the creator's edit form has a button that updates the data scan", [own_edit.fields.map { |field| field.key }, own_edit.fields[2].kind, own_edit.fields[2].label, own_edit.fields[2].group], [[:seats, :mods, :data, :description, :confirm], :button, "Update current data scan", "Game data"])
check("another editor's form does not", MGQ_MpWorld::Form.edit(listed[1]).fields.map { |field| field.key }, [:seats, :mods, :description, :confirm])
scene = new_scene
scene.instance_variable_set(:@me, "c")
scene.instance_variable_set(:@entry, entries[1])
form_window = scene.instance_variable_get(:@form_window)
form_window.define_singleton_method(:form=) { |form| @form = form }
form_window.define_singleton_method(:select) { |index| @index = index }
form_window.define_singleton_method(:field) { @form.fields[@index] }
scene.on_edit_world
form_window.select(2)
$calls.clear
scene.on_field
check("the button hands this game's data to the DLL at once, without asking", [$calls.last[0], $calls.last[2], scene.instance_variable_get(:@confirm_window).choices, scene.instance_variable_get(:@busy)], ["mp_dir_set_data", ["w2\0", "#{MGQ_MpWorld::GameData.fingerprint}\0"], nil, "data"])
$dll["mp_dir_action"] = "state=done\nkind=data\n\n"
scene.follow_action
check("and leaves the form open", [scene.form.title, said(scene)], ["Edit Loose", "The data scan of Loose was updated to your game."])
form_window.select(4)
$calls.clear
scene.on_field
check("the form's own button still saves the other changes", $calls.last[0], "mp_dir_edit")

# What the screen draws again.
again = MGQ_MpWorld::Entry.new(entries[1].id, entries[1].name, entries[1].listed.dup, nil, false, false)
check("the same world read again shows the same", again.signature == entries[1].signature, true)
changed = entries[1].listed.dup
changed.online = 3
check("a world that changed does not", MGQ_MpWorld::Entry.new(entries[1].id, entries[1].name, changed, nil, false, false).signature == entries[1].signature, false)
folder = MGQ_MpWorld::World.new("abcdef012345", "code" => "c", "name" => "Loose", "world" => "w2")
same_folder = MGQ_MpWorld::World.new("abcdef012345", "code" => "c", "name" => "Loose", "world" => "w2")
check("nor does a world whose folder was read again", MGQ_MpWorld::Entry.new("w2", "Loose", listed[1], folder, false, false).signature == MGQ_MpWorld::Entry.new("w2", "Loose", listed[1], same_folder, false, false).signature, true)
detail, texts = new_detail(386, 336)
detail.show(MGQ_MpWorld::Entry.new("w2", "Loose", listed[1], folder, false, false), "me")
texts.clear
detail.show(MGQ_MpWorld::Entry.new("w2", "Loose", listed[1], same_folder, false, false), "me")
check("so the details are not drawn again for it", texts, [])
