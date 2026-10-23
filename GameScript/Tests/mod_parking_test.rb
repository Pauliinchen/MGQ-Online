#----------------------------------------------------------------
#  mod_parking_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Left the create and edit calls of Turn off other mods to the DLL's tests
#                            - Left entering a world that turns other mods off to the DLL's tests and checked the steps the screen plays
#                            - Read the details and the list box's lines through the stand-ins of the world screen's model
#                            - Answered the parking topics in place of the parked mods' exports and left the decisions to the C# tests
#                            - Left the catalog's mods to the DLL's check, handed the world's new mods to it and dropped the stand-in for mp_mod_hash
#                            - Opened the world screen's forms through the DLL
#                            - Made the worlds on this PC through the stand-ins of the DLL's topics
#                            - Answered the mod catalog through the bridge
#                            - Answered the mod keys and the scripts in Patch through the bridge
#                            - Checked putting the mods back and starting again into the world in place of the restart by hand under Wine
#                            - Gave the stand-in world list every field the DLL writes
#                            - Dropped the check of the deleted options dump
#      Paulinchen  2026-10-22: Stood in for whether the version to install is a step back and for the update message
#      Paulinchen  2026-10-14: Expected a Raid World's row of its Save in every build
#      Paulinchen  2026-10-13: Expected the raid bosses of a Classic world in its edit form and after the squad rules in the DLL calls
#                            - Expected the row of a Raid World's squad rules' button and the squad rules after the other mods in the DLL calls
#      Paulinchen  2026-10-12: Stood in for Ini.load and the favourites and hidden worlds in Player.ini
#      Paulinchen  2026-10-10: Checked the restart for downloaded mods with and without parked mods
#                            - Checked failed parked restarts, mods not back on and linked scripts before a download
#                            - Checked linked scripts, conflicts, an unreadable journal, refused saves and the updater
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Checks the scripts' side of Turn off other mods (world_mods_parking.rbx, with world.rbx,
# world_mods.rbx and world_screen.rbx): the forms and the details, what the world screen does with
# the DLL's answers as a world is entered, the title screen's box, saves, the update and the relay's
# word that a world now turns other mods off. Which scripts park and when is the DLL's
# (ParkingSessionTests, ParkingRulesTests), so the parking topics answer as a test sets them.

require "fileutils"
require "tmpdir"

require_relative "support"
require_relative "rules_support"

# Stand-ins for the game.

# Stands in for the base of every scene, noting a return in $returned.
class Scene_Base; def return_scene; $returned = true; end; def update; end; end
# Stands in for the menu scenes' base.
class Scene_MenuBase < Scene_Base; end
# Stands in for the load screen.
class Scene_Load < Scene_Base; end
# Stands in for the map's screen, noting its fade-out in $faded.
class Scene_Map < Scene_Base; def fadeout_all; $faded = true; end; end
# Stands in for the base of every window.
class Window_Base; def initialize(*); end; end
# Stands in for a window with a cursor.
class Window_Selectable < Window_Base; end
# Stands in for a window of commands.
class Window_Command < Window_Selectable; end
# Stands in for the name entry's name line.
class Window_NameEdit < Window_Base; end
# Stands in for the name entry's letters.
class Window_NameInput < Window_Selectable; end
# Stands in for a color.
class Color; def initialize(*); end; end
# Stands in for a sprite.
class Sprite; def initialize(*); end; end
# Stands in for a rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# Stands in for the title screen.
class Scene_Title < Scene_Base; def start; end; def create_command_window; end; def update; end; def terminate; end; def scene_changing?; false; end; end
# Stands in for the title screen's commands.
class Window_TitleCommand; def make_command_list; end; end
# Stands in for the game's sounds, noting each in $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# Stands in for the game's input, the buttons in $buttons triggered.
module Input; def self.trigger?(button); ($buttons || []).include?(button); end; end
# Stands in for the scene manager, noting its calls, gotos and exit in $called, $went and $exited.
module SceneManager
  def self.call(scene); $called = scene; end
  def self.goto(scene); $went = scene; end
  def self.exit; $exited = true; end
  def self.scene; $scene || Object.new.tap { |scene| def scene.prepare(*); end }; end
end
# Stands in for the Mod Config screen.
class Scene_Config; end
# Stands in for the data manager, noting the saves in $saves.
module DataManager
  def self.save_system; end
  def self.load_game(_index); true; end
  def self.load_game_without_rescue(_index); true; end
  def self.setup_new_game; end
  def self.save_game(index); ($saves ||= []) << index; true; end
  def self.auto_save_game; ($saves ||= []) << :auto; true; end
end
# Stands in for the game's system with its config.
GameSystem = Struct.new(:conf)
$game_system = GameSystem.new({})
# Stands in for the game's config tables, whose mod entries hold only Return.
module NWConst; module Config; DEFAULT = {}; DATA = {}; DATA_TEXT = {}; MOD_CONTENTS = [{ :key => :return, :name => "Return" }]; end; end

# Stand-ins for the world room and the notification box.
$notices = []
# Stands in for the world room, keeping its routes and whether the map is free in $map_free.
module MGQ_MpOverworldSync
  # The field the relay tells a world's rule for other mods in.
  MODS_RULE_FIELD = "mods_rule_value"
  @routes = {}
  class << self; attr_reader :routes; end
  def self.route(field, &handler); @routes[field] = handler; end
  def self.on_observe(&_block); end
  def self.on_leave(&_block); end
  def self.state_fields(&_block); end
  def self.map_free?; $map_free; end
  # Stands in for the world room's players, each a Peer of seat and state.
  module Peers; Peer = Struct.new(:seat, :state); end
end
# Stands in for the notification box, keeping its messages in $notices.
module MGQ_MpNotices
  def self.message(key, text, _frames = 180); $notices << [key, text]; end
  def self.drop(key, _reason = ""); $notices.reject! { |known, _| known == key }; end
end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$dll = {}
$ini = {}
$restart = 1
# Stands in for the mod's base script, outdated only while $outdated is.
module MGQ_Multiplayer
  # The text that tells of an update.
  UPDATE_MESSAGE = "Update."
  # Gives the update message as it is.
  def self.update_message; UPDATE_MESSAGE; end
  def self.available?; true; end
  def self.outdated?; $outdated == true; end
  def self.clean(text); text; end
  def self.path(name); name; end
  def self.newer_version; "9.9.9"; end
  def self.rollback?; false; end
  # Stands in for the log, keeping its lines in $log.
  module Log; def self.write(message); ($log ||= []) << message; end; end
  # Stands in for the keyboard, no key pressed.
  module Key; def self.triggered?(_code); false; end; def self.pressed?(_code); false; end; end
  # Stands in for the mouse, never clicked.
  module Mouse; def self.clicked?; false; end; def self.position; nil; end; end
  # Stands in for the input capture, its owners in $captured and the buttons in $buttons triggered.
  module Capture
    def self.start(owner); ($captured ||= []) << owner; end
    def self.stop(owner); ($captured ||= []).delete(owner); end
    def self.trigger?(button); ($buttons || []).include?(button); end
  end
  # Stands in for Player.ini, its settings kept in $ini.
  module Player
    def self.share; end
    def self.name; "Me"; end
    def self.setting(key); $ini[key]; end
    def self.store(key, value); $ini[key] = value.to_s; end
    def self.keys_under(_prefix); []; end
  end
  # Stands in for the ini files, all of them empty.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; def self.write(_path, _values); true; end; end
  # Stands in for the DLL, its texts in $dll and its answers set by the test's globals.
  module Link
    # A DLL function that checks its arguments against its signature and notes each call in $calls.
    Function = Struct.new(:name, :signature) do
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, args]
        case name
        when "mp_restart_game" then $restart
        when "mp_update_game" then $update_answer || 1
        else 1
        end
      end
    end
    def self.function(name); Function.new(name, dll_signature(name)); end
    # Reads a DLL text from $dll.
    def self.read(name, _size)
      $dll[name].to_s
    end
    def self.open(_code); end
    def self.close; end
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
load_script "world_mods_parking"
load_script "world_text"
load_script "world_screen"
$fake = open_rules_bridge

# Stands in for the title screen's box, keeping what it shows in $box.
class Sprite_MpMessageBox
  def initialize; end
  def show(title, text, hint); $box = [title, text, hint]; end
  def dispose; $box = nil; end
end

# A small window of the world screen: keeps the commands it opened with.
class FakeChoice
  attr_reader :choices
  def start(choices); @choices = choices; end
  def finish; @choices = nil; end
  def activate; end
  def deactivate; end
  def unselect; end
  def active; !@choices.nil?; end
  def open?; active; end
  def index; -1; end
end

# The lines at the top of the world screen: keeps what they show.
class FakeInfo
  attr_reader :lines
  def show(lines); @lines = lines; end
end

# Builds the world screen without its windows.
#
# @return [Scene_MpWorlds] The screen.
def new_scene
  scene = Scene_MpWorlds.allocate
  [:@actions_window, :@members_window, :@confirm_window, :@start_window, :@list_window, :@form_window].each { |name| scene.instance_variable_set(name, FakeChoice.new) }
  scene.instance_variable_set(:@info_window, FakeInfo.new)
  scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::WorldForm.create(:new_world) })
  scene.instance_variable_set(:@list_state, "ready")
  scene
end

# Reads what the lines at the top of the world screen say, the player's name left out.
#
# @param scene [Scene_MpWorlds] The world screen.
# @return [String] The message.
def said(scene)
  scene.instance_variable_get(:@info_window).lines[1]
end

# Reads the commands of the world screen's question.
#
# @param scene [Scene_MpWorlds] The world screen.
# @return [Array<Symbol>, nil] The commands' symbols, nil while none is asked.
def asked(scene)
  choices = scene.instance_variable_get(:@confirm_window).choices
  choices && choices.map { |choice| choice[1] }
end

# Hands the mods module a catalog and forgets what it read before.
#
# @param lines [Array<String>] The catalog's lines, see catalog_told.
def catalog(*lines)
  catalog_told("ready", *lines)
  MGQ_MpWorldMods.forget_installed
end

# Starts a new session of the game: the parking script forgets what it showed and kept.
def new_session
  parking = MGQ_MpModParking
  [:@state, :@kick, :@box, :@box_shown, :@scene, :@frames].each { |name| parking.instance_variable_set(name, nil) }
  $parking_calls.clear if $parking_calls
  MGQ_MpWorldMods.rejoined
  $box = nil
  $exited = false
  $returned = false
end

# Builds a listed world.
#
# @param mods [String] Its mods.
# @param other_mods_off [Boolean] Whether it turns other mods off.
# @param open [Boolean] Whether it has no password.
# @return [MGQ_MpWorld::Directory::ListedWorld] The world.
def world_of(mods, other_mods_off = true, open = true)
  MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, "creator", 0, "Creator", "Strict", "none", [], false, false, open, false, false, "", mods, "", "", "", "classic", "off", nil, other_mods_off)
end

parking = MGQ_MpModParking

# The DLL's parking: what each topic answers, set by the test, and the requests it got.
$parking_calls = []
$parking_answers = {}
$parking_state = PARKING_IDLE.dup

# What the parking topics that tell no state answer unless a test sets otherwise: nothing to turn off.
PARKING_DEFAULTS = {
  "change" => { "kind" => "none", "plan" => [], "text" => nil, "also" => "", "claimed" => false, "moved" => false },
  "plan" => { "plan" => [], "mods" => [] }, "parked_for" => { "parked" => false, "text" => "" },
  "rule" => { "taken" => true, "kick" => nil }, "take_kick" => nil,
}
%w(change plan parked_for join restart_for_mods rule take_kick title_started title_left entered give_up restart_now notice_closed tell update_started state).each do |topic|
  $fake.answer("parking.#{topic}") do |request|
    $parking_calls << [topic, request]
    told = $parking_answers.key?(topic) ? $parking_answers[topic] : PARKING_DEFAULTS.key?(topic) ? PARKING_DEFAULTS[topic] : $parking_state
    told.respond_to?(:call) ? told.call(request) : told
  end
end

# Sets what the parking topics of the title screen's flow answer as the state.
#
# @param changes [Hash] The fields of the state that differ from nothing parked.
def parking_state(changes)
  $parking_state = PARKING_IDLE.merge(changes)
end

# Lists the parking topics called since the last look, without the state reads.
#
# @return [Array<String>] Their names, such as "join".
def parking_called
  called = $parking_calls.map(&:first) - ["state"]
  $parking_calls.clear
  called
end

# The list and the catalog.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tw1\t4\t0\tc\t0\tCreator\tStrict\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\tclassic\toff\t\t1\t\t0\n" \
  "world\tw2\t4\t0\tc\t0\tCreator\tLoose\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\traid\tstory\t1\t0\t\t0\n" \
  "world\tw3\t4\t0\tc\t0\tCreator\tOld raid\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\traid\tstory\t1\t1\t\t0\n" \
  "world\tw4\t4\t0\tc\t0\tCreator\tOld\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\tclassic\toff\t\t0\t\t0\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads whether a world turns other mods off", listed.map { |world| world.other_mods_off }, [true, false, true, false])

catalog_told("failed")
MGQ_MpWorldMods.forget_installed
check("while the catalog is unknown, so are the personal mods", MGQ_MpWorldMods.personal_keys, nil)
catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "personal\tvictoryscreen\tVictory Screen", "personal\tnowplaying\tNow_Playing")
check("the catalog's personal lines name the personal mods by key, those without a download too", MGQ_MpWorldMods.personal_keys, ["victoryscreen", "nowplaying"])

Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch", "Sub"))
  %w[Level_Cap.rb Invasions.rb Victory_Screen.rb Sub/Extra-Mod.rb].each { |name| File.write(File.join(folder, "Patch", name), "") }

  Dir.chdir(folder) do
    strict = world_of("!Level Cap; ?Luka Replacer")
    local = local_world("abcdef", "code" => "x", "name" => "Strict")

    # The forms and the details.
    form = MGQ_MpWorld::WorldForm.create(:new_world)
    other = form.fields.find { |field| field.key == :other_mods_off }
    type = form.fields.find { |field| field.key == :type }
    check("the new world's form has Turn off other mods below Shared Mod Settings, unticked for a Classic world",
          [other.kind, other.label, other.group, other.row, form[:other_mods_off]], [:check, "Turn off other mods", "Game data", 8, false])
    check("whose hint fits the lines at the top and tells that personal mods stay", [other.hint.size <= 100, other.hint.include?("Personal mods stay on")], [true, true])
    form.turn(type, 1)
    check("a Raid World ticks it", form.other_mods_off?, true)
    form.tick(:other_mods_off)
    form.turn(type, 1)
    form.turn(type, 1)
    check("once the player unticked it, the type no longer changes it", form.other_mods_off?, false)
    edit = MGQ_MpWorld::WorldForm.edit(:edit_world, strict, false)
    check("the edit form has it for an admin too, ticked as the world is", [edit.fields.map { |field| field.key }, edit[:other_mods_off]], [[:seats, :raid_bosses, :mods, :other_mods_off, :description, :confirm], true])

    $parking_answers["plan"] = { "plan" => ["Patch/Invasions.rb", "Patch/Luka_Replacer.rb", "Patch/Luka_Replacer/hero.rb"], "mods" => [["Invasions", 1], ["Luka_Replacer", 2]] }
    detail = screen_detail
    rows = lambda { |world| detail.data_panel(MGQ_MpWorld::Entry.new("w1", "Strict", world, nil, false, false), "me").rows.map { |cells| cells.map { |cell| cell.text } } }
    check("the details count the player's mods a world turns off", [rows.call(strict)[2], parking_called], [["Other mods: turned off (2 of yours)"], ["plan"]])
    check("or tell that it allows them, asking nothing", [rows.call(world_of("", false))[2], parking_called], [["Other mods: allowed"], []])
    check("the mods box adds them, counting a mod's scripts", screen_detail.mod_lines("Level Cap", nil, nil, parking.turned_off_mods(strict)).last(3),
          [[:head, "Your mods turned off here (2)"], [:item, "Invasions", :grey, "yours, turned off here"], [:item, "Luka_Replacer", :grey, "yours, 2 scripts, turned off here"]])
    $parking_answers["plan"] = { "plan" => nil, "mods" => [] }
    check("while they are unknown, the details only say that it turns them off", rows.call(strict)[2], ["Other mods: turned off"])
    $parking_answers.delete("plan")

    # Entering a world that turns other mods off, whose steps the DLL decides (WorldEnteringTests).
    question = "These mods are turned off while you play in Strict: Invasions and Sub. Restart and join?"
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    $screen_steps = [["say", question], ["confirm", "parking", [["Restart and join", "yes"], ["See the mods", "show_mods"], ["Back", "cancel"]]]]
    scene.on_enter
    check("the parking question of the DLL's steps shows with its commands", [said(scene), asked(scene)], [question, [:yes, :show_mods, :cancel]])
    $screen_steps = [["exit"]]
    scene.on_confirmed
    check("yes goes back to the DLL, whose exit step closes the game", [screen_requests("screen.answer").last, $exited], [{ "answer" => "yes" }, true])
    $exited = false

    # The start after the restart and the title screen.
    new_session
    parking_state("holding" => true)
    Scene_Title.new.start
    check("the title screen tells the DLL it starts, which holds the mods for the world entered again", [parking_called, parking.holding?], [["title_started", "title_left"], true])
    scene = new_scene
    $returned = false
    scene.play("steps" => [["say", "The world you restarted for is not in the list right now."], ["give_up", "The world you restarted for is not in the list right now."]])
    check("the give-up step has the DLL put the mods back, with why, and leaves the screen",
          [$parking_calls.find { |call| call[0] == "give_up" }[1], $returned], [{ "reason" => "The world you restarted for is not in the list right now." }, true])

    new_session
    parking_state("due" => "Your mods are back after a restart.")
    title = Scene_Title.new
    Scene_Title.new.start
    parking.on_title_update(title)
    check("a restart due shows the box with why", $box, ["Turning your mods back on", "Your mods are back after a restart.", "The game starts again in a moment."])
    $parking_answers["restart_now"] = PARKING_IDLE.merge("restarting" => true)
    parking_called
    (MGQ_MpModParking::RESTART_FRAMES - 2).times { parking.on_title_update(title) }
    check("and waits its time", [parking_called, $exited], [[], false])
    parking.on_title_update(title)
    check("then has the DLL start the game again, and closes", [parking_called, $exited, parking.title_busy?], [["restart_now"], true, false])
    $parking_answers.delete("restart_now")

    new_session
    parking_state("notice" => "Some of your mods could not be turned back on.")
    Scene_Title.new.start
    parking.on_title_update(title)
    check("a notice shows until the player closes it", $box, ["Turning your mods back on", "Some of your mods could not be turned back on.", "Enter, Esc or Numpad 0: close"])
    parking_state({})
    $buttons = [:C]
    parking.on_title_update(title)
    $buttons = []
    check("who closes it, which the DLL is told", [parking_called.include?("notice_closed"), parking.title_busy?, $box], [true, false, nil])

    # Saving without the other mods.
    new_session
    parking_state("saving_off" => true, "save_text" => "Saving is off until your other mods are back. Start the game again to bring them back.")
    Scene_Title.new.start
    $saves = []
    $notices.clear
    check("while the DLL says saving is off, no game is saved outside a world, and a save the player makes is told why",
          [DataManager.save_game(0), DataManager.auto_save_game, $saves, $notices],
          [false, false, [], [[:mod_parking, "Saving is off until your other mods are back. Start the game again to bring them back."]]])
    MGQ_MpWorld.instance_variable_set(:@world, local)
    check("while saving in a world stays on", [DataManager.save_game(1), $saves], [true, [1]])
    MGQ_MpWorld.instance_variable_set(:@world, nil)
    parking_state({})
    new_session
    Scene_Title.new.start
    check("as it does while the DLL says it is on", [DataManager.save_game(2), $saves], [true, [1, 2]])

    # The update.
    $parking_calls.clear
    MGQ_MpWorld::UpdateOffer.instance_variable_set(:@box, Sprite_MpMessageBox.new)
    $update_answer = 0
    MGQ_MpWorld::UpdateOffer.update_and_install
    check("an updater that could not start leaves the mods alone", [parking_called, $exited], [[], false])
    $update_answer = nil
    MGQ_MpWorld::UpdateOffer.update_and_install
    check("one that started has the DLL put them back before the game closes for it", [parking_called, $exited], [["update_started"], true])
    new_session

    # The relay's word that the open world now turns other mods off.
    route = MGQ_MpOverworldSync.routes[MGQ_MpOverworldSync::MODS_RULE_FIELD]
    online = local_world("abcdef", "code" => "x", "name" => "Strict", "world" => "w1")
    MGQ_MpWorld.instance_variable_set(:@world, online)
    MGQ_MpWorldMods.enter_world(strict, "me")
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap")
    check("a push not from the relay is ignored", parking_called, [])
    $parking_answers["rule"] = { "taken" => false, "kick" => nil }
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "2", "mods" => "Other", :relay => true)
    check("one the DLL does not take changes nothing", $settings_calls.any? { |call| call == ["settings.mods", "Other"] }, false)
    $parking_answers["rule"] = { "taken" => true, "kick" => nil }
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "0", "mods" => "Level Cap; Invasions", :relay => true)
    check("the relay's word goes to the DLL with the open world, and the world's mods change",
          [$parking_calls.last[1], $settings_calls.last, parking.instance_variable_get(:@kick)],
          [{ "value" => "0", "mods" => "Level Cap; Invasions", "open" => true, "world" => "w1", "name" => "Strict" }, ["settings.mods", "Level Cap; Invasions"], nil])
    $parking_answers["rule"] = { "taken" => true, "kick" => "Strict now turns off other mods. Enter it again to play." }
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap", :relay => true)
    $map_free = false
    $scene = Scene_Map.new
    $notices.clear
    MGQ_MpModParking::KICK_FRAMES.times { parking.tick }
    check("a world that turns the player's mods off tells the player, and waits for the map to be free", [$notices, $went], [[[:mod_parking, "Strict now turns off other mods. Enter it again to play."]], nil])
    $map_free = true
    parking_called
    parking.tick
    check("then goes to the title screen, which the DLL has tell it again", [$went, $faded, $parking_calls.find { |call| call[0] == "tell" }[1]],
          [Scene_Title, true, { "text" => "Strict now turns off other mods. Enter it again to play." }])
    $parking_answers.delete("rule")

    MGQ_MpWorld.instance_variable_set(:@world, online)
    $parking_answers["take_kick"] = "Strict now turns off other mods. Enter it again to play."
    $fake.post("worlds.changed", MGQ_MpWorld::Changes::PARKING)
    MGQ_Multiplayer::Bridge.frame
    $went = nil
    $notices.clear
    (MGQ_MpModParking::KICK_FRAMES + 1).times { parking.tick }
    check("a check the DLL made against a fetched list tells the player the same", [$notices.size, $went], [1, Scene_Title])
    $parking_answers.delete("take_kick")
    parking_called
    MGQ_MpWorld.instance_variable_set(:@world, online)
    parking.entered
    check("entering a world hands the DLL its id and name, to check it against a list fetched now", $parking_calls.find { |call| call[0] == "entered" }[1], { "world" => "w1", "name" => "Strict" })
    MGQ_MpWorld.instance_variable_set(:@world, nil)
    $scene = nil
  end
end
