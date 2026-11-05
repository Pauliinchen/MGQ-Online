#----------------------------------------------------------------
#  world_screen_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the list, the details, the choices, the list box, the forms and the mod picker with the values each check sets instead of their stand-ins
#                            - Read the directory's list and the player's id through the DLL's topics
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# Checks the world screen on the Mod Framework's components (world_screen.rbx): the worlds and the
# commands as boxes the keys stop on as a whole first, a world's details and what they open, a
# world's choices and the DLL's questions in the framework's menu and question box, the forms built
# from the DLL's view and typed in place, the formation limits, the mod picker, the cursor on a world
# just made, and the screen held while the DLL's action runs. The rules behind it are the DLL's.

require_relative "support"
require_relative "rules_support"
require "tmpdir"

# Stands in for the game's scenes: returning notes $returned.
class Scene_Base; def start; end; def update; end; def terminate; end; def scene_changing?; false; end; def return_scene; $returned = true; end; end
# Stands in for the game's menu scenes.
class Scene_MenuBase < Scene_Base; end
# Stands in for the load screen.
class Scene_Load < Scene_Base; end
# Stands in for the game's windows, which draw nothing.
class Window_Base; def initialize(*); end; end
# Stands in for a window with a cursor.
class Window_Selectable < Window_Base; end
# Stands in for a window of commands.
class Window_Command < Window_Selectable; end
# Stands in for a colour.
class Color; def initialize(*); end; end
# Stands in for a sprite, which draws nothing.
class Sprite; def initialize(*); end; end
# A rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the title screen, whose steps do nothing.
class Scene_Title; def start; end; def create_command_window; end; def close_command_window; end; def update; end; def terminate; end; end
# Stands in for the title's commands, which list none.
class Window_TitleCommand; def make_command_list; end; end
# Stands in for the sounds: each one played goes into $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end

# Stands in for the scene manager.
module SceneManager
  # Records the scene called in $called.
  def self.call(scene); $called = scene; end

  # Gives a scene that takes any preparation.
  def self.scene; Object.new.tap { |scene| def scene.prepare(*); end }; end
end

# Stands in for saving the system data, which saves nothing.
module DataManager; def self.save_system; end; end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$outdated = false

# Stands in for the mod's base script: available, and outdated while $outdated.
module MGQ_Multiplayer
  # What an outdated game is told.
  UPDATE_MESSAGE = "Update."

  # Gives the update message, for a step back with the version to play, from $rollback.
  def self.update_message; $rollback ? "#{newer_version} is the version to play now." : UPDATE_MESSAGE; end

  # Answers that the mod is available.
  def self.available?; true; end

  # Answers whether the game is outdated, from $outdated.
  def self.outdated?; $outdated; end

  # Gives the newer version while the game is outdated.
  def self.newer_version; $outdated ? "9.9.9" : nil; end

  # Answers whether the version to install is a step back, from $rollback.
  def self.rollback?; $rollback == true; end

  # Gives the text as it is.
  def self.clean(text); text; end

  # Gives the path as it is.
  def self.path(name); name; end

  # Stands in for the log, which writes nothing.
  module Log; def self.write(_message); end; end

  # Stands in for Player.ini: its settings are in $player_ini, and it cannot be read while
  # $player_ini_unreadable.
  module Player
    # Shares nothing.
    def self.share; end

    # The player's name, Me.
    def self.name; "Me"; end

    # Reads a setting.
    def self.setting(key); ($player_ini ||= {})[key]; end

    # Lists the keys under a prefix, without it.
    def self.keys_under(prefix); ($player_ini ||= {}).keys.select { |key| key.start_with?(prefix) }.map { |key| key[prefix.size..-1] }; end

    # Answers whether Player.ini can be read.
    def self.readable?; !$player_ini_unreadable; end

    # Changes settings, unless Player.ini cannot be read.
    #
    # @param changes [Hash{String => String, nil}] The values by key, nil removing a key.
    # @return [Boolean] Whether they were changed.
    def self.change(changes)
      return false if $player_ini_unreadable

      changes.each { |key, value| ($player_ini ||= {}).delete(key); $player_ini[key] = value unless value.nil? }
      true
    end
  end

  # Stands in for the ini files, which read empty.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; end

  # Stands in for holding the buttons: the owner holding them is in $capture, the button pressed in
  # $pressed.
  module Mod_Framework::UI::Capture
    # Holds the buttons for an owner.
    def self.start(owner); $capture = owner; end

    # Gives the buttons back if the owner holds them.
    def self.stop(owner); $capture = nil if $capture == owner; end

    # Answers whether a button is pressed, from $pressed.
    def self.trigger?(button); $pressed == button; end

    # Answers whether a button repeats, as it is pressed.
    def self.repeat?(button); trigger?(button); end
  end

  # Stands in for the mouse, never clicked.
  module Mod_Framework::UI::Mouse; def self.clicked?; false; end; end

  # Stands in for the player's id, as the DLL tells it.
  module Player; def self.id; "me"; end; end
end

require_relative "world_screen_support"
load_script "world_save_distribution"
load_script "ui_online"
load_script "world"
load_script "world_mods"
load_script "world_screen"
open_rules_bridge
open_fake_ui { typed = $typed.to_s; $typed = nil; [typed, typed.size] }



ui = Mod_Framework::UI
LISTED = [listed_value("w1", "Sunset", "online" => 1, "creator_name" => "Cara", "mods" => "Level Cap;Party Sheet", "description" => "A slow run.",
                       "members" => [["c", true, "Cara"], ["ana", false, "Ana"], ["me", false, "Me"]]),
          listed_value("w2", "Iliasburg", "creator_id" => "me", "creator_name" => "Me", "members" => [["me", true, "Me"]])]
# The list's rows in the DLL's order, Iliasburg first.
ROWS = [listed_row(LISTED[1]), listed_row(LISTED[0])]
$screens.details["w1"] = screen_details("Sunset", ["Level Cap", "Party Sheet"], ["Cara", "Ana", "Me (you)"], "A slow run.")
$screens.actions["w1"] = [["Enter the world", "enter", true], ["Mark as a favourite", "favourite", true], ["Back", "cancel", true]]
$screens.actions["w2"] = [["Enter the world", "enter", true], ["Remove a player", "ban", false], ["Back", "cancel", true]]
$screens.boxes[["w1", "players"]] = [["head", "Online (1)"], ["item", "Cara", "good", "online"], ["head", "Offline (2)"], ["item", "Ana", "grey", "offline"],
                                     ["item", "Me (you)", "grey", "offline"]]
$screens.boxes[["w1", "mods"]] = [["head", "Mods (2)"], ["item", "Level Cap", "plain", nil], ["item", "Party Sheet", "plain", nil]]

# Opening: the commands' box as a whole until the worlds arrive, then the worlds' box.
screen_list([], "loading", "info" => "The list is being fetched . . .")
scene = world_scene
commands_box = scene.instance_variable_get(:@commands_box)
worlds_box = scene.instance_variable_get(:@worlds_box)
check("the screen opens with the commands' box picked as a whole, the strip naming the player and how the list stands",
      [$focused.equal?(commands_box), strip_text(scene).split("\n").values_at(0, 2)], [true, ["You play as Me.", "The list is being fetched . . ."]])
screen_list(ROWS)
scene.look_at_list
check("the first worlds to arrive take the pick onto the worlds' box as a whole, the rows as the DLL wrote them",
      [$focused.equal?(worlds_box), scene.worlds_list.rows.map { |row| row[:text] }], [true, ["Iliasburg", "Sunset"]])

# The boxes and the right side.
scene.worlds_list.index = 1
ui::Tree.focus(scene.worlds_list)
scene.show_panel
texts = lambda { |part| part.children.map { |child| texts.call(child) }.flatten + (part.respond_to?(:text) && part.text.is_a?(String) ? [part.text] : []) }
shown = texts.call(scene.right_box)
check("in the worlds the right side shows the world's details: its name, its panels and its description",
      [shown.include?("Sunset"), shown.include?("A slow run."), %w(World Players Description).all? { |title| shown.include?(title) }], [true, true, true])
plate = scene.right_box.find(:details_mods)
check("a cell that opens something is one part the player clicks, its values as tags",
      [plate.clickable, plate.body.children.first.class, plate.cancel_to.equal?(scene.worlds_list)], [true, ui::Tags, true])
scene.right_box.find(:details_players).receive("click")
box = scene.list_box
check("clicking the players opens the list box with the DLL's rows of the world's players",
      [$screens.asked("screen.box").last, box.open?, note_text(box), MGQ_MpListBox.list(box).rows[3]],
      [{ "key" => "w1", "kind" => "players" }, true, "Players", { :text => "Ana", :color => :dim, :right => "offline" }])
box.close

# The details by the keys, as C# moves the focus: Right on a world onto Mods, Down to Players, Left
# back to the same world.
ui::Tree.focus(scene.worlds_list)
ui::Tree.focus(scene.right_box.find(:details_mods))
scene.show_panel
check("Right on a world puts the focus on its Mods, the details still shown", [scene.instance_variable_get(:@place), texts.call(scene.right_box).include?("Sunset")], [:details, true])
ui::Tree.focus(scene.right_box.find(:details_players))
ui::Tree.focus(scene.worlds_list)
scene.show_panel
check("Down then goes to Players, and Left back to the same world, its details still shown",
      [scene.worlds_list.index, scene.instance_variable_get(:@place), texts.call(scene.right_box).include?("Sunset")], [1, :worlds, true])
ui::Tree.focus(commands_box)
check("on a box as a whole the right side shows nothing", (scene.show_panel; scene.right_box.children.size), 0)

# A world's choices.
scene.worlds_list.receive("submit", 1)
check("confirm on a world opens its choices in the framework's menu, Back last", [menu_texts.first, menu_texts.last], ["Enter the world", "Back"])
cancel_menu(scene)
check("cancel on the menu backs out of it", [ui::Menu.current, scene.idle?], [nil, true])
scene.worlds_list.receive("submit", 1)
pick_menu(scene, menu_texts.index("Mark as a favourite"))
check("a choice picked goes to the DLL in the frame after", screen_requests("screen.do").last.values_at("do", "id"), ["favourite", "w1"])

# The players to remove, and the question before.
scene.worlds_list.receive("submit", 0)
check("a choice the DLL greys, such as Remove a player with one player, is greyed in the menu", menu_enabled[menu_texts.index("Remove a player")], false)
cancel_menu(scene)
entry = scene.worlds_list.rows[1][:data]
scene.instance_variable_set(:@entry, entry)
scene.on_ban
check("a world with others lists them", menu_texts, ["Cara", "Ana", "Back"])
pick_menu(scene, 1)
check("picking one asks first, in the question box, and says it in the strip", [$asked.last, said(scene)],
      [["Remove Ana from Sunset? They cannot enter it again.", ["Remove them", "Back"]], "Remove Ana from Sunset? They cannot enter it again."])
answer_question(scene, true)
check("Remove them hands the DLL the player", screen_requests("screen.do").last.values_at("do", "target", "target_name"), ["ban", "ana", "Ana"])

# The DLL's questions.
scene.instance_variable_set(:@entry, entry)
scene.play("steps" => [["say", "Turn your other mods off to enter?"], ["confirm", "other_mods", [["Turn them off", "yes"], ["Back", "cancel"]]]])
check("a question of one doing command and Back goes to the question box with what the steps said",
      $asked.last, ["Turn your other mods off to enter?", ["Turn them off", "Back"]])
answer_question(scene, false)
check("its Back answers back", screen_requests("screen.answer").last, { "answer" => "back" })
scene.play("steps" => [["say", "Sunset needs a mod you lack."], ["confirm", "mods", [["Download", "yes"], ["See the mods", "show_mods"], ["Back", "cancel"]]]])
check("a question of more commands goes to the menu", menu_texts, ["Download", "See the mods", "Back"])
pick_menu(scene, 1)
check("See the mods tells the DLL and opens the list box with the world's mods",
      [screen_requests("screen.answer").last, note_text(scene.list_box)], [{ "answer" => "show_mods" }, "Mods"])
scene.list_box.close
scene.play("steps" => [["choices", [["At the beginning", "from_beginning"], ["From one of my saves", "from_own"], ["Back", "cancel"]]]])
cancel_menu(scene)
check("cancel on the choices of where to start answers back", screen_requests("screen.answer").last, { "answer" => "back" })

# Busy, the focus dropped as C#'s tree drops it on an inert root.
$sounds = []
ui::Tree.focus(scene.worlds_list)
scene.play("steps" => [["busy", "create"]])
check("while the DLL's action runs the screen takes no input and the strip says what runs", [scene.root.inert?, said(scene)], [true, MGQ_MpWorldScreen.busy_text("create")])
check("and it is not waiting for the player", scene.idle?, false)
$focused = nil
$returned = false
scene.root.receive("cancel")
check("cancel on the screen while it runs leaves nothing", [$returned, scene.root.open?, scene.busy], [false, true, "create"])
scene.play("steps" => [["idle"]])
check("once it ended the screen takes input again, the worlds holding the focus as before",
      [scene.root.inert?, scene.busy, $focused.equal?(scene.worlds_list)], [false, nil, true])

# Forms: a command's form shows as a preview, confirm enters it typing.
ui::Tree.focus(scene.commands_list)
scene.commands_list.index = 0
scene.show_panel
name = form_part(scene, :name)
preview = scene.right_box.children.first
check("on Create new world its form shows, one part only the pointer clicks", [name.class, preview.clickable, preview.pointer_only], [ui::TextField, true, true])
preview.receive("click")
check("a click on it moves into it, onto Name", [scene.form.nil?, $focused.equal?(form_part(scene, :name))], [false, true])
cancel_in($focused)
scene.commands_list.receive("submit", 0)
name = form_part(scene, :name)
check("confirm moves into it, onto Name, typing, with its hint and the typing line",
      [$focused.equal?(name), $mgq_text_input, said(scene), (scene.show_typing_line; scene.instance_variable_get(:@typing_line).visible)],
      [true, true, scene.form.fields.first.hint, true])
$forms.set("form.check", ["", "The world needs a name."])
type_in("\r")
check("Enter on an empty name has the DLL check it, buzzes, says why and keeps typing",
      [$forms.asked("form.check").last.values_at("form", "key", "text"), $sounds.last, said(scene), $focused.equal?(name)], [["new_world", "name", ""], "buzzer", "The world needs a name.", true])
$forms.set("form.check")
type_in("Sunrise\r")
check("a name taken goes into the form and the focus moves down", [scene.form[:name], $focused.equal?(form_part(scene, :password))], ["Sunrise", true])
scene.say("")
form_part(scene, :seats).receive("hover", true)
check("the pointer on a field says its hint", said(scene), scene.form.fields.find { |field| field.key == :seats }.hint)
check_field = scene.form.fields.find { |field| field.kind == :check }
ui::Tree.focus(form_part(scene, check_field.key))
check("on a checkbox the typing line hides", (scene.show_typing_line; scene.instance_variable_get(:@typing_line).visible), false)
seats = form_part(scene, :seats)
check("Max Players takes digits only", seats.allowed =~ "a", nil)

# A switch turned asks the DLL for the form anew, the focus kept.
type = form_part(scene, :type)
ui::Tree.focus(type)
check("a Classic world's form has no Difficulty", form_part(scene, :difficulty), nil)
$forms.set("form.turn", FormAnswers.view("create turned to a Raid World"))
type.receive("step", 1)
$forms.set("form.turn")
check("turning World type has the DLL turn it and builds the form anew from its answer, with Difficulty, the focus on World type",
      [$forms.asked("form.turn").last.values_at("key", "step"), scene.form.type, form_part(scene, :difficulty).nil?, $focused.equal?(type) || form_part(scene, :type).id == type.id],
      [["type", 1], "raid", false, true])

# The formation limits.
form_part(scene, :limits).receive("click")
check("Set formation limits opens them over the form", [scene.limits.open?, scene.limits.title], [true, "Formation limits"])
scene.limits.close(:cancel)
check("closing them goes back to the form at their button", [scene.limits, scene.instance_variable_get(:@field_key)], [nil, :limits])
form_part(scene, :limits).receive("click")
ui::Tree.focus(scene.limits.find("form:done"))
scene.limits.find("form:done").receive("click")
check("Done closes them the same way", [scene.limits, scene.instance_variable_get(:@field_key)], [nil, :limits])

# Sending with a problem focuses the field that keeps it.
scene.form[:name] = ""
form_part(scene, :name).text = ""
$forms.set("form.send", "problem" => ["name", "The world needs a name."])
form_part(scene, :confirm).receive("click")
$forms.set("form.send")
check("sending a form with a problem the DLL names buzzes, says why and puts the focus on the field", [said(scene), $focused.id], ["The world needs a name.", "form:name"])

# Cancel in a command's form keeps it, in the edit form drops it.
type_in("Kept")
cancel_in($focused)
check("cancel in the create form goes back to its command, keeping what was typed", [scene.form, scene.instance_variable_get(:@forms)[:new_world][:name], $focused.equal?(scene.commands_list)],
      [nil, "Kept", true])
scene.instance_variable_set(:@entry, scene.worlds_list.rows[0][:data])
scene.on_edit_world
check("Edit the world opens its form on the world as it is listed, titled as the DLL answers",
      [$forms.asked("form.open").last.values_at("form", "kind") + $forms.asked("form.open").last["world"].values_at("name", "seats"), scene.form.title],
      [["edit_world", "edit", "Iliasburg", 4], FormAnswers.view("edit of a Classic world, by an admin")["title"]])
cancel_in($focused)
check("cancel in the edit form drops it and goes back to the worlds", [scene.instance_variable_get(:@forms).key?(:edit_world), $focused.equal?(scene.worlds_list)], [false, true])

# Leaving a form sideways, onto a box as a whole, leaves it as cancel does.
scene.commands_list.receive("submit", 0)
ui::Tree.focus(commands_box)
check("moving from the create form onto the commands' box leaves the form, keeping it, the focus where it went",
      [scene.form, scene.instance_variable_get(:@forms).key?(:new_world), $focused.equal?(commands_box), scene.idle?], [nil, true, true, true])
scene.on_edit_world
ui::Tree.focus(worlds_box)
check("moving from the edit form onto the worlds' box drops it", [scene.form, scene.instance_variable_get(:@forms).key?(:edit_world)], [nil, false])

# The password step.
scene.instance_variable_set(:@entry, scene.worlds_list.rows[1][:data])
scene.play("steps" => [["password", "Sunset"]])
check("the password step opens its form typing, the password shown as stars",
      [$forms.asked("form.open").last.values_at("kind", "name"), form_part(scene, :password).mask, $mgq_text_input], [["password", "Sunset"], "*", true])
type_in("secret\r")
check("Enter hands the password to the DLL", screen_requests("screen.answer").last, { "answer" => "password", "text" => "secret" })
cancel_in($focused)
check("cancel in it leaves it and tells the DLL", [scene.form, screen_requests("screen.answer").last], [nil, { "answer" => "password_back" }])

# The mod picker.
scene.commands_list.receive("submit", 0)
$locals.set("modpick.open", "entries" => [["Level_Cap", "unlisted", true, "unlisted", "grey"]], "text" => "", "all_listed" => false)
$locals.set("modpick.act", "answer" => nil,
            "pick" => { "entries" => [["Level_Cap", "unlisted", true, "unlisted", "grey"], ["Old Mod", "listed", false, "listed", "plain"]], "text" => "Old Mod", "all_listed" => false })
form_part(scene, :mods).receive("click")
pick = scene.list_box
list = MGQ_MpListBox.list(pick)
check("Mods opens the mod picker over the form, the row of every installed mod first", [pick.open?, list.rows.first[:data]], [true, :all])
add = list.rows.index { |row| row[:data] == :add }
list.receive("submit", add)
check("Add a mod by name opens the Name field, typing", [pick.find(MGQ_MpListBox::FIELD_ROW).visible, $focused.equal?(MGQ_MpListBox.field(pick))], [true, true])
type_in("Old Mod\r")
added = list.rows.index { |row| row[:text] == "Old Mod" }
check("a name typed goes to the DLL, and the mod it added is picked, the Remove button showing on it",
      [$locals.asked("modpick.act").last, added.nil?, list.index == added, MGQ_MpListBox.remove_button(pick).visible], [{ "do" => "add", "name" => "Old Mod" }, false, true, true])
pick.close(:cancel)
check("closing the picker shows the mods in the form", [scene.list_box, form_part(scene, :mods).text], [nil, "Old Mod"])

# A world just made gets the cursor once listed, but not after the player moved on.
cancel_in(form_part(scene, :mods))
scene.play("steps" => [["select", "w3"]])
NEW_DAWN = listed_row(listed_value("w3", "New Dawn", "creator_id" => "me", "creator_name" => "Me"))
screen_list(ROWS + [NEW_DAWN])
scene.look_at_list
check("a world just made gets the cursor in the worlds once the list shows it",
      [$focused.equal?(scene.worlds_list), scene.current_entry.name], [true, "New Dawn"])
scene.play("steps" => [["select", "w4"]])
scene.commands_list.receive("submit", 2)
screen_list(ROWS + [NEW_DAWN, listed_row(listed_value("w4", "Later", "creator_id" => "me", "creator_name" => "Me"))])
scene.look_at_list
check("but not once the player moved into a form", [scene.form.nil?, scene.current_entry.name == "Later"], [false, false])
cancel_in($focused)

# A world waiting to be entered, such as a Discord invite's, waits for the player.
$screen_waiting = true
scene.instance_variable_set(:@waiting, true)
scene.worlds_list.receive("submit", 0)
scene.look_at_list
check("the DLL hears that the screen does not wait for the player while a menu is open", screen_requests("screen.do").last.values_at("do", "idle"), ["look", false])
cancel_menu(scene)
scene.look_at_list
check("and that it does once the menu closed", screen_requests("screen.do").last.values_at("do", "idle"), ["look", true])
$screen_waiting = nil
scene.instance_variable_set(:@waiting, nil)

# Back from the save screen, which returns to the same scene, the cursor is on the world chosen before.
ui::Tree.focus(scene.worlds_list)
scene.instance_variable_set(:@entry, scene.worlds_list.rows.find { |row| row[:data].name == "Sunset" }[:data])
scene.worlds_list.index = 0
scene.terminate
scene.start
screen_changed
scene.look_at_list
check("back from the save screen the cursor is on the world chosen before", [scene.current_entry.name, $focused.equal?(scene.worlds_list)], ["Sunset", true])
worlds_box = scene.instance_variable_get(:@worlds_box)
commands_box = scene.instance_variable_get(:@commands_box)

# The last world gone moves the pick to the commands.
ui::Tree.focus(scene.worlds_list)
screen_list([])
scene.look_at_list
check("the last world gone picks the commands' box as a whole", $focused.equal?(commands_box), true)

# Cancel while the DLL's action runs.
$sounds = []
scene.play("steps" => [["busy", "delete"]])
Mod_Framework::UI.define_singleton_method(:cancel?) { |*_| true }
scene.buzz_while_busy
check("cancel while an action runs only buzzes", [$sounds, scene.busy], [["buzzer"], "delete"])

# The first start without a name.
$returned = false
MGQ_Multiplayer::Player.define_singleton_method(:name) { nil }
scene = world_scene
scene.update
check("without a name the name form opens typing", [scene.form.title.empty?, $mgq_text_input], [false, true])
name = form_part(scene, :name)
ui::Tree.focus(scene.commands_list)
check("Left out of the empty name onto the commands keeps the screen and the form, the focus back on the name",
      [$returned, scene.instance_variable_get(:@form_symbol), $focused.equal?(name)], [false, :rename, true])
screen_list(ROWS)
scene.look_at_list
scene.commands_list.receive("submit", 0)
scene.worlds_list.receive("submit", 0)
check("and so does a click on a command or a world", [$returned, scene.instance_variable_get(:@form_symbol), ui::Menu.current, $focused.equal?(name)],
      [false, :rename, nil, true])
cancel_in($focused)
check("leaving it without a name closes the screen", $returned, true)
