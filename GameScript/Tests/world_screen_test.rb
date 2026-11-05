#----------------------------------------------------------------
#  world_screen_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Dropped the stand-ins of the mouse and the held buttons, which no check reads
#                            - Checked that mods the Mod Framework finds ready while the DLL finds them differing refuse the entry
#                            - Reached the Mod Framework's engine under its own name
#                            - Checked the screen as its window of the UI layer hands over what the player does, the mods a world needs going to the Mod Framework's dialog
#      Paulinchen  2026-11-05: Answered the list, the details, the choices, the list box, the forms and the mod picker with the values each check sets instead of their stand-ins
#                            - Read the directory's list and the player's id through the DLL's topics
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# Checks the world screen (world_screen.rbx) as its window of the UI layer hands over what the player
# does: the boxes the focus goes to, what the right side shows, a world's choices and the DLL's
# questions in the framework's menu and question box, the mods a world needs in the Mod Framework's
# dialog, the forms from the DLL's view, the formation limits, the mod picker, the cursor on a world
# just made, and the screen held while the DLL's action runs. How the layer draws it is the in-game
# suite's (32_step9_b_worlds.rb); the rules behind it are the DLL's.

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

  # Stands in for the player's id, as the DLL tells it.
  module Player; def self.id; "me"; end; end
end

# The action after the framework's restart that enters a world again.
module MGQ_Multiplayer; module Stages; REJOIN_ACTION = "multiplayer.rejoin" unless const_defined?(:REJOIN_ACTION); end; end

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

# Opening: the commands' box as a whole until the worlds arrive, then the worlds' box.
screen_list([], "loading", "info" => "The list is being fetched . . .")
scene = world_scene
check("the screen opens with the commands' box picked as a whole, the lines at the top naming the player and how the list stands",
      [focused(scene), scene.strip_lines], [:commands_box, ["You play as Me.", "The list is being fetched . . ."]])
screen_list(ROWS)
scene.look_at_list
check("the first worlds to arrive pick the worlds' box as a whole, the rows as the DLL wrote them",
      [focused(scene), scene.entries.map { |entry| scene.world_row(entry)[:text] }], [:worlds_box, ["Iliasburg", "Sunset"]])

# The boxes and the right side.
scene.entered(:worlds)
scene.pointed_world(scene.entries[1])
check("in the worlds the right side shows the world the cursor is on", [scene.right_view[0], scene.right_view[1].name], [:world, "Sunset"])
scene.entered(:commands)
scene.pointed_command(Scene_MpWorlds::COMMANDS[3])
check("on Back of the commands the right side shows nothing", scene.right_view, nil)

# A world's choices.
scene.on_world(scene.entries[1])
check("confirm on a world opens its choices in the framework's menu, Back last", [menu_texts.first, menu_texts.last], ["Enter the world", "Back"])
cancel_menu(scene)
check("cancel on the menu backs out of it", [menu_texts, scene.idle?], [nil, true])
scene.on_world(scene.entries[1])
pick_menu(scene, menu_texts.index("Mark as a favourite"))
check("a choice picked goes to the DLL in the frame after", screen_requests("screen.do").last.values_at("do", "id"), ["favourite", "w1"])

# The players to remove, and the question before.
scene.on_world(scene.entries[0])
check("a choice the DLL greys, such as Remove a player with one player, is greyed in the menu", menu_enabled[menu_texts.index("Remove a player")], false)
cancel_menu(scene)
entry = scene.entries[1]
scene.instance_variable_set(:@entry, entry)
scene.on_ban
check("a world with others lists them", menu_texts, ["Cara", "Ana", "Back"])
pick_menu(scene, 1)
check("picking one asks first, in the question box, and says it in the lines at the top", [$asked.last, said(scene)],
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
scene.play("steps" => [["choices", [["At the beginning", "from_beginning"], ["From one of my saves", "from_own"], ["Back", "cancel"]]]])
check("a question of more commands goes to the menu", menu_texts, ["At the beginning", "From one of my saves", "Back"])
cancel_menu(scene)
check("cancel on the choices of where to start answers back", screen_requests("screen.answer").last, { "answer" => "back" })

# The mods a world needs go to the Mod Framework's dialog.
needed = nil
Mod_Framework::Mods.define_singleton_method(:ask_needed) { |place, mods, options = {}, &block| needed = [place, mods, options, block]; :asking }
scene.play("steps" => [["needed_mods", "Sunset", [{ "name" => "Level Cap", "version" => "1.4.0", "differs" => false }, { "name" => "Mod C", "version" => nil, "differs" => true }]]])
check("a world whose mods differ asks the Mod Framework, which starts the game again into that world where it must",
      [needed[0], needed[1], needed[2][:restart]],
      ["Sunset", [{ :name => "Level Cap", :version => "1.4.0", :differs => false }, { :name => "Mod C", :version => nil, :differs => true }], ["multiplayer.rejoin", "w1"]])
check("and the screen waits for it", scene.idle?, false)
needed[3].call(:ready)
run_later(scene)
check("once the mods are ready the DLL goes on entering", screen_requests("screen.answer").last, { "answer" => "mods_ready" })
scene.play("steps" => [["needed_mods", "Sunset", [{ "name" => "Mod C", "differs" => true }]]])
needed[3].call(:back)
run_later(scene)
check("going back from the dialog gives the entry up", screen_requests("screen.answer").last, { "answer" => "back" })
Mod_Framework::Mods.define_singleton_method(:ask_needed) { |place, mods, options = {}, &block| block.call(:ready); :ready }
answers = screen_requests("screen.answer").size
scene.play("steps" => [["needed_mods", "Sunset", [{ "name" => "Level Cap", "version" => "1.4.0", "differs" => true }]]])
run_later(scene)
check("mods the Mod Framework finds ready at once while the DLL found them differing refuse the entry instead of going on",
      [said(scene), screen_requests("screen.answer").drop(answers), scene.idle?],
      ["Sunset needs mods that differ here, which the Mod Framework cannot change: Level Cap. Check the Patch folder, then try again.", [{ "answer" => "back" }], true])

# Busy.
$sounds = []
scene.entered(:worlds)
scene.play("steps" => [["busy", "create"]])
check("while the DLL's action runs the screen says what runs and does not wait for the player", [said(scene), scene.idle?], [MGQ_MpWorldScreen.busy_text("create"), false])
$returned = false
scene.cancelled
scene.on_world(scene.entries[0])
check("cancel and a pick while it runs only buzz", [$returned, $sounds, menu_texts], [false, ["buzzer", "buzzer"], nil])
scene.play("steps" => [["idle"]])
check("once it ended the worlds take the focus as before", [scene.busy, focused(scene)], [nil, :worlds])

# Forms: a command's form shows as a preview, confirm enters it typing.
scene.entered(:commands)
scene.pointed_command(Scene_MpWorlds::COMMANDS[0])
check("on Create new world its form shows as a preview", scene.right_view, [:preview, :new_world])
scene.enter_preview
check("a click on it moves into it, onto Name", [scene.right_view, focused(scene)], [[:form, :new_world], :name])
cancel_form(scene)
scene.on_command(Scene_MpWorlds::COMMANDS[0])
check("confirm moves into it, onto Name", [scene.form_symbol, focused(scene)], [:new_world, :name])
scene.left(:commands)
$forms.set("form.check", ["", "The world needs a name."])
type_in("\r")
check("Enter on an empty name has the DLL check it, buzzes and says why, the focus staying",
      [$forms.asked("form.check").last.values_at("form", "key", "text"), $sounds.last, said(scene), focused(scene)], [["new_world", "name", ""], "buzzer", "The world needs a name.", :name])
$forms.set("form.check")
type_in("Sunrise\r")
check("a name taken goes into the form and the focus moves down", [scene.form[:name], focused(scene)], ["Sunrise", :password])
check("Max Players is a number the player types or steps", form_field(scene, :seats).kind, :number)

# A switch turned asks the DLL for the form anew.
check("a Classic world's form has no Difficulty", form_field(scene, :difficulty), nil)
$forms.set("form.turn", FormAnswers.view("create turned to a Raid World"))
scene.turned(scene.form, form_field(scene, :type), 1)
$forms.set("form.turn")
check("turning World type has the DLL turn it and shows the form anew from its answer, with Difficulty",
      [$forms.asked("form.turn").last.values_at("key", "step"), scene.form.type, form_field(scene, :difficulty).nil?], [["type", 1], "raid", false])

# The formation limits.
scene.pressed(form_field(scene, :limits))
check("Set formation limits opens them over the form", scene.limits && scene.limits.open?, true)
scene.limits.close
check("closing them goes back to the form at their button", [scene.limits, focused(scene)], [nil, :limits])

# Sending with a problem focuses the field that keeps it.
$forms.set("form.send", "problem" => ["name", "The world needs a name."])
scene.pressed(form_field(scene, :confirm))
$forms.set("form.send")
check("sending a form with a problem the DLL names buzzes, says why and puts the focus on the field", [said(scene), focused(scene)], ["The world needs a name.", :name])

# Cancel in a command's form keeps it, in the edit form drops it.
type_in("Kept")
cancel_form(scene)
check("cancel in the create form goes back to its command, keeping what was typed", [scene.form, scene.forms[:new_world][:name], scene.right_view], [nil, "Kept", [:preview, :new_world]])
scene.instance_variable_set(:@entry, scene.entries[0])
scene.on_edit_world
check("Edit the world opens its form on the world as it is listed, titled as the DLL answers",
      [$forms.asked("form.open").last.values_at("form", "kind") + $forms.asked("form.open").last["world"].values_at("name", "seats"), scene.form.title],
      [["edit_world", "edit", "Iliasburg", 4], FormAnswers.view("edit of a Classic world, by an admin")["title"]])
cancel_form(scene)
check("cancel in the edit form drops it and goes back to the worlds", [scene.forms.key?(:edit_world), scene.right_view[0]], [false, :world])

# The password step.
scene.instance_variable_set(:@entry, scene.entries[1])
scene.play("steps" => [["password", "Sunset"]])
check("the password step opens its form, the focus on the password", [$forms.asked("form.open").last.values_at("kind", "name"), form_field(scene, :password).kind, focused(scene)],
      [["password", "Sunset"], :password, :password])
type_in("secret\r")
check("Enter hands the password to the DLL", screen_requests("screen.answer").last, { "answer" => "password", "text" => "secret" })
cancel_form(scene)
check("cancel in it leaves it and tells the DLL", [scene.form, screen_requests("screen.answer").last], [nil, { "answer" => "password_back" }])

# The mod picker.
scene.on_command(Scene_MpWorlds::COMMANDS[0])
$locals.set("modpick.open", "entries" => [["Level_Cap", "unlisted", true, "unlisted", "grey"]], "text" => "", "all_listed" => false)
$locals.set("modpick.act", "answer" => nil,
            "pick" => { "entries" => [["Level_Cap", "unlisted", true, "unlisted", "grey"], ["Old Mod", "listed", false, "listed", "plain"]], "text" => "Old Mod", "all_listed" => false })
scene.open_mod_pick
check("Mods opens the mod picker over the form: the row of every installed mod, the installed ones, then the row that adds one",
      [scene.list_box && scene.list_box.open?, scene.mod_pick_items, scene.mod_pick_row(0)[:toggles].map { |toggle| toggle[:text] }],
      [true, [:all, "Your mods (1)", 0, :add], ["!", "?"]])
check("a name added goes to the DLL, which lists it under its own heading, Remove taking it out", [scene.add_mod("Old Mod"), $locals.asked("modpick.act").last, scene.mod_pick_items, scene.added_mod?(1)],
      [true, { "do" => "add", "name" => "Old Mod" }, [:all, "Your mods (1)", 0, "Added by name (1)", 1, :add], true])
$locals.set("modpick.act", "answer" => "Level_Cap is in the list already.", "pick" => { "entries" => [["Level_Cap", "unlisted", true, "unlisted", "grey"]], "text" => "", "all_listed" => false })
$sounds = []
scene.act_on_mod(0, 1)
check("a change the DLL refuses buzzes and names why beside the title", [$sounds, scene.mod_pick_note], [["buzzer"], "Level_Cap is in the list already."])
scene.list_box.close
check("closing the picker shows the mods in the form, back at their field", [scene.list_box, scene.form[:mods], focused(scene)], [nil, "", :mods])
cancel_form(scene)

# A world just made gets the cursor once listed, but not after the player moved on.
scene.play("steps" => [["select", "w3"]])
NEW_DAWN = listed_row(listed_value("w3", "New Dawn", "creator_id" => "me", "creator_name" => "Me"))
screen_list(ROWS + [NEW_DAWN])
scene.look_at_list
check("a world just made gets the cursor in the worlds once the list shows it", [focused(scene), scene.current_entry.name], [:worlds, "New Dawn"])
scene.play("steps" => [["select", "w4"]])
scene.on_command(Scene_MpWorlds::COMMANDS[2])
screen_list(ROWS + [NEW_DAWN, listed_row(listed_value("w4", "Later", "creator_id" => "me", "creator_name" => "Me"))])
scene.look_at_list
check("but not once the player moved into a form", [scene.form.nil?, scene.current_entry.name == "Later"], [false, false])
cancel_form(scene)

# A world waiting to be entered, such as a Discord invite's, waits for the player.
$screen_waiting = true
scene.instance_variable_set(:@waiting, true)
scene.on_world(scene.entries[0])
scene.look_at_list
check("the DLL hears that the screen does not wait for the player while a menu is open", screen_requests("screen.do").last.values_at("do", "idle"), ["look", false])
cancel_menu(scene)
scene.look_at_list
check("and that it does once the menu closed", screen_requests("screen.do").last.values_at("do", "idle"), ["look", true])
$screen_waiting = nil
scene.instance_variable_set(:@waiting, nil)

# Back from the save screen, which returns to the same scene, the cursor is on the world chosen before.
scene.instance_variable_set(:@entry, scene.entries.find { |each| each.name == "Sunset" })
scene.pointed_world(scene.entries[0])
scene.terminate
scene.start
screen_changed
scene.look_at_list
check("back from the save screen the cursor is on the world chosen before", [scene.current_entry.name, focused(scene)], ["Sunset", :worlds])

# The last world gone moves the pick to the commands.
scene.entered(:worlds)
screen_list([])
scene.look_at_list
check("the last world gone picks the commands' box as a whole", focused(scene), :commands_box)

# The first start without a name.
$returned = false
MGQ_Multiplayer::Player.define_singleton_method(:name) { nil }
scene = world_scene
scene.update
check("without a name the name form opens on its field", [scene.form_symbol, focused(scene)], [:rename, :name])
scene.left(:commands)
scene.entered(:commands)
check("moving onto the commands keeps the screen and the form, the focus back on the name", [$returned, scene.form_symbol, focused(scene)], [false, :rename, :name])
screen_list(ROWS)
scene.look_at_list
scene.on_command(Scene_MpWorlds::COMMANDS[0])
scene.on_world(scene.entries[0])
check("and so does a pick of a command or a world", [$returned, scene.form_symbol, menu_texts, focused(scene)], [false, :rename, nil, :name])
cancel_form(scene)
check("leaving it without a name closes the screen", $returned, true)
