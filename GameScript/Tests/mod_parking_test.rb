#----------------------------------------------------------------
#  mod_parking_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-13: Expected the row of a Raid World's squad rules' button and the squad rules after the other mods in the DLL calls
#      Paulinchen  2026-10-12: Stood in for Ini.load and the favourites and hidden worlds in Player.ini
#      Paulinchen  2026-10-10: Checked the restart for downloaded mods with and without parked mods
#                            - Checked failed parked restarts, mods not back on and linked scripts before a download
#                            - Checked linked scripts, conflicts, an unreadable journal, refused saves and the updater
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Checks Turn off other mods (world_mods_parking.rbx, with world.rbx, world_mods.rbx and
# world_screen.rbx): the catalog's personal mods, the scripts a world turns off, the forms and the
# details, entering such a world through a restart, the start after it, the way back to the title
# screen, the start after a game that closed with mods parked, and the relay's word that a world
# now turns other mods off.

require "fileutils"
require "tmpdir"

require_relative "support"

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

# Stand-ins for the mod's base script and its DLL, which keeps the parked scripts in $parked.
$sounds = []
$calls = []
$dll = {}
$ini = {}
$parked = []
$restart = 1
$restart_parked = 1
$recover = 0
# Stands in for the mod's base script, outdated only while $outdated is.
module MGQ_Multiplayer
  # The text that tells of an update.
  UPDATE_MESSAGE = "Update."
  def self.available?; true; end
  def self.outdated?; $outdated == true; end
  def self.clean(text); text; end
  def self.path(name); name; end
  def self.newer_version; "9.9.9"; end
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
        when "mp_mods_park"
          return 0 if $park_fails

          $parked = args[0].chomp("\0").split("\n")
          $parked = $parked.first(1) if $park_partly
          $parked_for = args[1].chomp("\0")
          $parked.size
        when "mp_mods_restore"
          return -2 if $restore_held
          return -1 if $restore_fails

          count = $parked.size
          $parked = []
          count
        when "mp_mods_restart_parked" then $restart_parked
        when "mp_mods_recover" then $restore_held ? -2 : $recover
        when "mp_restart_game" then $restart
        when "mp_update_game" then $update_answer || 1
        when "mp_mod_hash" then 0
        else 1
        end
      end
    end
    def self.function(name); Function.new(name, dll_signature(name)); end
    # Reads a DLL text: the scripts, the parked mods' journal built from $parked, or $dll's entry.
    def self.read(name, _size)
      return scripts.b if name == "mp_mods_scripts"
      return $dll[name].to_s unless name == "mp_mods_parked"
      return $parked_text if $parked_text
      return "" if $parked.empty? && !$conflicts

      "world=#{$parked.empty? ? '' : $parked_for}\nfiles=#{$parked.size}\nconflicts=#{$conflicts || 0}\n\n#{$parked.join("\n")}"
    end
    # Lists the scripts the DLL could park as mp_mods_scripts does: those behind a link to another
    # drive (from $elsewhere) first, then the Patch folder's and the parked ones, leaving out this
    # mod's own folder and the scripts every player has.
    def self.scripts
      raise "mp_mods_scripts failed" if $scripts_fail
      return $scripts_text if $scripts_text

      shared = lambda { |path| path.downcase.start_with?("patch/multiplayer/") || %w[patch multiplayer 0modconfigremake].include?(MGQ_MpWorld.mod_key(File.basename(path))) }
      found = Dir.glob("Patch/**/*.rb").reject { |path| shared.call(path) || $parked.include?(path) }
      found -= $elsewhere || []
      ((($elsewhere || []).map { |path| "elsewhere\t#{path}\n" }) + found.map { |path| "patch\t#{path}\n" } + $parked.map { |path| "parked\t#{path}\n" }).join
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
  scene.instance_variable_set(:@forms, { :new_world => MGQ_MpWorld::Form.create })
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
# @param lines [Array<String>] The catalog's lines.
def catalog(*lines)
  $dll["mp_mods_list"] = "state=ready\n\n" + lines.map { |line| line + "\n" }.join
  MGQ_MpWorldMods.forget_installed
end

# Starts a new session of the game: the parking script forgets everything but the files.
def new_session
  parking = MGQ_MpModParking
  [:@started, :@hold, :@kept_at_start, :@owned, :@due, :@notice, :@by_hand, :@kick, :@box, :@box_shown, :@scene, :@start_parked, :@recheck, :@last_state].each { |name| parking.instance_variable_set(name, nil) }
  parking.instance_variable_set(:@title_starts, 0)
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

# The list and the catalog.
$dll["mp_dir_list"] = "state=ready\n\n" \
  "world\tw1\t4\t0\tc\t0\tCreator\tStrict\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\tclassic\toff\t\t1\n" \
  "world\tw2\t4\t0\tc\t0\tCreator\tLoose\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\traid\tstory\t1\t0\n" \
  "world\tw3\t4\t0\tc\t0\tCreator\tOld raid\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\traid\tstory\t1\n" \
  "world\tw4\t4\t0\tc\t0\tCreator\tOld\tnone\t0\t0\t1\t0\t0\t\t\t\t\t\t\t\t\n"
_, _, listed, = MGQ_MpWorld::Directory.list
check("the list reads whether a world turns other mods off, by its type when the relay does not tell", listed.map { |world| world.other_mods_off }, [true, false, true, false])

$dll["mp_mods_list"] = "state=failed\nerror=down\n\n"
MGQ_MpWorldMods.forget_installed
check("while the catalog is unknown, so are the personal mods", MGQ_MpWorldMods.personal_keys, nil)
catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "personal\tvictoryscreen\tVictory Screen", "personal\tnowplaying\tNow_Playing")
check("the catalog's personal lines name the personal mods by key, those without a download too, which are no catalog mods",
      [MGQ_MpWorldMods.personal_keys, MGQ_MpWorldMods.catalog.map(&:key)], [["victoryscreen", "nowplaying"], ["levelcap"]])
$dll["mp_mods_list"] = "state=loading\n\n"
MGQ_MpWorldMods.forget_installed
check("and stay known while the list is fetched again", MGQ_MpWorldMods.personal_keys, ["victoryscreen", "nowplaying"])

Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch", "Multiplayer"))
  FileUtils.mkdir_p(File.join(folder, "Patch", "Sub"))
  FileUtils.mkdir_p(File.join(folder, "Patch", "Luka_Replacer"))
  %w[Patch.rb Multiplayer.rb 0_ModConfigRemake.rb Level_Cap.rb Invasions.rb Victory_Screen.rb Luka_Replacer.rb Sub/Extra-Mod.rb Multiplayer/Multiplayer.rb Multiplayer/Old_Backup.rb Luka_Replacer/hero.txt Luka_Replacer/heroes.rb].each do |name|
    File.write(File.join(folder, "Patch", name), "")
  end

  Dir.chdir(folder) do
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "personal\tvictoryscreen\tVictory Screen")

    # Which scripts a world turns off.
    check("a world turns off every script it does not name, but the personal ones and those every player has, a folder's by the folder's mod",
          parking.to_turn_off("!Level Cap; ?Luka Replacer"), ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"])
    check("a script belongs to the folder right under the Patch folder, or to itself right in it",
          ["Patch/Luka_Replacer/heroes.rb", "Patch\\Sub\\Deep\\x.rb", "Patch/Invasions.rb", "Patch/Odd.RB"].map { |path| [parking.owner_name(path), parking.owner_key(path)] },
          [["Luka_Replacer", "lukareplacer"], ["Sub", "sub"], ["Invasions", "invasions"], ["Odd", "odd"]])
    check("nor any script in this mod's own folder, which the DLL never parks", [parking.shared?("Patch/Multiplayer/Old_Backup.rb"), parking.shared?("Patch\\multiplayer\\Old_Backup.rb"), parking.shared?("Patch/Multiplayers.rb")],
          [true, true, false])
    check("a world that names a mod in any way keeps it, whatever its case and spaces", parking.to_turn_off("level cap; Invasions; sub; luka-replacer"), [])
    check("naming a script in a mod's folder keeps nothing of it", parking.to_turn_off("Level Cap; Luka Replacer; Invasions; Extra Mod"), ["Patch/Sub/Extra-Mod.rb"])
    $scripts_text = "patch\tPatch/Übersetzung.rb\nparked\tPatch/Invasions.rb\nparked\tPatch/Invasions.rb\npatch\tPatch/Multiplayer/Old.rb\nother\tPatch/X.rb\n\n"
    found = parking.scripts
    check("the scripts come from the DLL in UTF-8, each once, whatever their names hold",
          [found, found.map { |path| path.encoding }.uniq], [["Patch/Übersetzung.rb", "Patch/Invasions.rb"], [Encoding::UTF_8]])
    $calls.clear
    parking.park(parking.to_turn_off("Level Cap"), "w1")
    check("and go back to it as they came", $calls.find { |call| call[0] == "mp_mods_park" }[1][0].force_encoding("UTF-8"), "Patch/Invasions.rb\nPatch/Übersetzung.rb\0")
    $parked = []
    $scripts_text = nil
    new_session
    $scripts_fail = true
    check("when the DLL cannot list the scripts, a world that turns other mods off is not entered", [parking.to_turn_off(""), parking.change_for(world_of("")), parking.change_for(world_of("", false))], [nil, :unlisted, nil])
    $scripts_fail = false
    new_session
    $scripts_text = "error"
    check("when the DLL answers that it could not list the scripts, the world is not entered either",
          [parking.scripts, parking.change_for(world_of(""))], [nil, :unlisted])
    $scripts_text = nil
    new_session
    check("a world that allows other mods turns none off", parking.plan_for(world_of("", false)), [])
    $dll["mp_mods_list"] = "state=failed\n\n"
    MGQ_MpWorldMods.forget_installed
    check("while the catalog is unknown the scripts to turn off are too", [parking.to_turn_off(""), parking.change_for(world_of(""))], [nil, :unknown])
    check("unless the world names every script anyway", parking.to_turn_off("Level Cap; Invasions; Sub; Luka Replacer; Victory Screen"), [])
    catalog("personal\tvictoryscreen\tVictory Screen")
    strict = world_of("!Level Cap; ?Luka Replacer")
    check("with nothing parked, the change is parking them", parking.change_for(strict), ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"])
    check("the question names their mods", parking.confirm_text("Strict", parking.change_for(strict)),
          "These mods are turned off while you play in Strict: Invasions and Sub. Restart and join?")

    # The forms and the details.
    form = MGQ_MpWorld::Form.create
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
    check("the form keeps to the screen: the Raid-only and Classic-only rows share one, and a development build's Raid World adds the row of its squad rules' button",
          [form.fields.map { |field| field.row }.uniq.size, (form.turn(type, 1); form.fields.map { |field| field.row }.uniq.size)], [11, 10])
    MGQ_MpWorld::Directory.create("W", "", 4, false, false, "", :type => "raid")
    check("create sends a Raid World with other mods off unless told otherwise", $calls.last[1][-2], 1)
    MGQ_MpWorld::Directory.create("W", "", 4, false, false, "")
    check("and a Classic world with them allowed", $calls.last[1][-2], 0)
    MGQ_MpWorld::Directory.create("W", "", 4, false, false, "", :type => "raid", :other_mods_off => false)
    check("or as the form says", $calls.last[1][-2], 0)
    MGQ_MpWorld::Directory.edit("w1", 4, "", "", nil, nil, true)
    check("an edit sends it with its flag when it changed", $calls.last[1][-3..-2], [1, 1])
    MGQ_MpWorld::Directory.edit("w1", 4, "", "")
    check("and leaves it otherwise", $calls.last[1][-3..-2], [0, 0])
    edit = MGQ_MpWorld::Form.edit(strict)
    check("the edit form has it for an admin too, ticked as the world is", [edit.fields.map { |field| field.key }, edit[:other_mods_off]], [[:seats, :mods, :other_mods_off, :description, :confirm], true])

    detail = Window_MpWorldDetail.allocate
    rows = lambda { |world| detail.data_panel(MGQ_MpWorld::Entry.new("w1", "Strict", world, nil, false, false), "me").rows.map { |cells| cells.map { |cell| cell.text } } }
    check("the details say how many of the player's mods a world turns off", rows.call(strict)[2], ["Other mods: turned off (2 of yours)"])
    check("or that it allows them", rows.call(world_of("", false))[2], ["Other mods: allowed"])
    scene = new_scene
    check("the mods box lists the player's mods it turns off", scene.mod_lines(strict.mods, nil, nil, parking.plan_for(strict)),
          [[:head, "Mods (2)"], [:item, "Level Cap", :good, "required, installed"], [:item, "Luka Replacer", :gold, "essential, not checked"],
           [:head, "Your mods turned off here (2)"], [:item, "Invasions", :grey, "yours, turned off here"], [:item, "Sub", :grey, "yours, turned off here"]])
    loose = world_of("!Level Cap")
    check("one line per mod, counting its scripts, in the box and the details", [scene.mod_lines(loose.mods, nil, nil, parking.plan_for(loose)).last(4), rows.call(loose)[2]],
          [[[:head, "Your mods turned off here (3)"], [:item, "Invasions", :grey, "yours, turned off here"], [:item, "Luka_Replacer", :grey, "yours, 2 scripts, turned off here"],
            [:item, "Sub", :grey, "yours, turned off here"]], ["Other mods: turned off (3 of yours)"]])
    $scripts_fail = true
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, MGQ_MpWorld::World.new("abcdef", "code" => "x", "name" => "Strict"), false, false))
    scene.on_enter
    check("a world is not entered while the DLL cannot list the scripts", [said(scene), asked(scene)], ["Your Patch folder could not be read, so you cannot enter Strict now. See the log.", nil])
    $scripts_fail = false

    # Scripts behind a link to another drive, which the DLL cannot park.
    $elsewhere = ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"]
    check("scripts behind a link to another drive are none the DLL parks", [parking.scripts.include?("Patch/Invasions.rb"), parking.elsewhere], [false, $elsewhere])
    check("they keep the game out of a world that turns them off, not of one that names them or allows other mods",
          [parking.change_for(strict), parking.change_for(world_of("Level Cap; Invasions; Sub; Luka Replacer")), parking.change_for(world_of("", false))], [:elsewhere, nil, nil])
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, MGQ_MpWorld::World.new("abcdef", "code" => "x", "name" => "Strict"), false, false))
    $calls.clear
    scene.on_enter
    check("entering it says how many and names the first, moving nothing",
          [said(scene), asked(scene), $calls.map(&:first).include?("mp_mods_park")],
          ["2 mod scripts lie on another drive behind a link in Patch and cannot be turned off: Patch/Invasions.rb.", nil, false])
    $elsewhere = ["Patch/Sub/Extra-Mod.rb"]
    check("or that one does", parking.elsewhere_text(strict), "1 mod script lies on another drive behind a link in Patch and cannot be turned off: Patch/Sub/Extra-Mod.rb.")
    $elsewhere = nil

    # Entering a world that turns other mods off.
    strict.mods = "Level Cap; ?Luka Replacer"
    local = MGQ_MpWorld::World.new("abcdef", "code" => "x", "name" => "Strict")
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    entered = []
    scene.define_singleton_method(:enter) { |*args| entered << args }
    scene.on_enter
    check("entering asks first, naming the mods it turns off", [said(scene), asked(scene), entered],
          ["These mods are turned off while you play in Strict: Invasions and Sub. Restart and join?", [:yes, :show_mods, :cancel], []])
    $calls.clear
    scene.on_confirmed
    check("yes parks them for the world, notes the world to enter and starts the game again into it",
          [$parked, $parked_for, $ini["rejoin"], $calls.find { |call| call[0] == "mp_mods_restart_parked" }[1], $exited], [["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"], "w1", "w1", ["w1\0", 1], true])
    $exited = false

    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.define_singleton_method(:enter) { |*args| entered << args }
    scene.on_enter
    check("the session that parked them still runs them, so it never enters", [said(scene), asked(scene), entered.size],
          ["Your mods were turned off or on since the game started. Restart it first, then enter Strict.", nil, 0])

    new_session
    $recover = 2
    $ini["rejoin"] = "w1"
    Scene_Title.new.start
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.define_singleton_method(:enter) { |*args| entered << args }
    scene.on_enter
    check("the start after the restart, with them parked, enters the world at once", [asked(scene), entered.size], [nil, 1])
    $dll["mp_mods_list"] = "state=failed\n\n"
    MGQ_MpWorldMods.forget_installed
    check("and keeps them parked while the catalog is unknown, since they were parked with a known one", parking.change_for(strict), nil)
    catalog("personal\tvictoryscreen\tVictory Screen")

    classic = world_of("", false)
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Classic", classic, local, false, false))
    scene.on_enter
    check("a world that allows them asks before putting them back", [said(scene), asked(scene), $parked.size],
          ["Classic allows your turned-off mods, which come back after a restart. Restart and join?", [:yes, :cancel], 2])
    $restart = 2
    scene.on_confirmed
    check("under Wine they come back and the player restarts by hand", [$parked, $ini["rejoin"], said(scene)],
          [[], "w1", "Your mods are back on. Restart the game by hand: it enters Classic once it is back."])
    $restart = 1
    $recover = 0
    $ini["rejoin"] = ""
    new_session

    $parked = ["Patch/Invasions.rb"]
    $parked_for = "w9"
    $restore_held = true
    Scene_Title.new.start
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Classic", classic, local, false, false))
    scene.on_enter
    scene.on_confirmed
    check("while another game of this folder holds them, they stay off and that is said, nothing restarting",
          [$parked.size, $exited, said(scene), parking.title_busy?], [1, false, MGQ_MpModParking::HELD_TEXT, false])
    $restore_held = false
    $parked = []
    new_session

    # The journal names the world entered when the mods parked for another are those it turns off.
    $parked = ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"]
    $parked_for = "w9"
    $recover = 2
    $ini["rejoin"] = "w9"
    Scene_Title.new.start
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    entered = []
    scene.define_singleton_method(:enter) { |*args| entered << args }
    $calls.clear
    scene.on_enter
    check("entering a world that turns off the same mods parks them for it, moving nothing, and enters",
          [$calls.find { |call| call[0] == "mp_mods_park" }[1], $parked_for, $parked.size, parking.moved_here?, asked(scene), entered.size],
          [["Patch/Invasions.rb\nPatch/Sub/Extra-Mod.rb\0", "w1\0"], "w1", 2, false, nil, 1])
    $calls.clear
    parking.claim(strict)
    check("and asks nothing more once the journal names it", $calls.map(&:first).include?("mp_mods_park"), false)
    $parked_for = "w9"
    check("mods parked for another world that differ are not parked for this one", [parking.claim(world_of("Level Cap; Invasions")), $parked_for], [false, "w9"])
    $parked = []
    $recover = 0
    $ini["rejoin"] = ""
    new_session

    $parked = []
    $park_partly = true
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.on_enter
    $calls.clear
    scene.on_confirmed
    check("a park that moved only some puts them back and restarts nothing", [$parked, $calls.map(&:first) & ["mp_mods_restore", "mp_mods_restart_parked"], said(scene)],
          [[], ["mp_mods_restore"], "Your other mods could not be turned off, so you cannot enter Strict now. See the log."])
    $park_partly = false
    new_session

    full_strict = world_of("Level Cap; ?Luka Replacer")
    full_strict.online = 4
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", full_strict, local, false, false))
    scene.on_enter
    check("a full world is refused before anything is turned off", [said(scene), asked(scene), $parked], ["Strict is full right now.", nil, []])

    $parked = []
    $ini["rejoin"] = ""
    $restart_parked = 2
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.on_enter
    scene.on_confirmed
    check("under Wine the mods stay parked and the world noted for the start the player makes", [$parked.size, $ini["rejoin"], $exited, said(scene)],
          [2, "w1", false, "Your other mods are turned off. Restart the game by hand: it enters Strict once it is back."])
    Scene_Title.new.start
    check("the title screen then leaves them parked", [$parked.size, parking.title_busy?], [2, false])
    new_session

    $parked = []
    $ini["rejoin"] = ""
    $restart_parked = 0
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.on_enter
    scene.on_confirmed
    check("when the game cannot start again, the mods come back and the world is not entered", [$parked, $ini["rejoin"], said(scene)],
          [[], "", "The game could not start again, so your mods stay on and Strict was not entered."])
    $restart_parked = 1

    $park_fails = true
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.on_enter
    $calls.clear
    scene.on_confirmed
    check("when the scripts cannot be moved, nothing restarts", [$parked, $calls.map(&:first).include?("mp_mods_restart_parked"), said(scene)],
          [[], false, "Your other mods could not be turned off, so you cannot enter Strict now. See the log."])
    $park_fails = false

    $dll["mp_mods_list"] = "state=failed\n\n"
    MGQ_MpWorldMods.forget_installed
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.on_enter
    check("while the catalog is unknown the world is not entered", [said(scene), asked(scene)], ["The mod catalog has not loaded yet. Try again in a moment.", nil])
    catalog("personal\tvictoryscreen\tVictory Screen")

    locked = world_of("Level Cap; ?Luka Replacer", true, false)
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", locked, nil, false, false))
    asked_password = []
    scene.define_singleton_method(:ask_password) { asked_password << true }
    scene.on_enter
    check("a world this PC never entered asks its password first", [asked_password, asked(scene)], [[true], nil])
    found = MGQ_MpWorld::World.new("fedcba", "code" => "y", "name" => "Strict")
    MGQ_MpWorld::World.define_singleton_method(:found) { |*_args| found }
    check("and once the lock opened, keeps the world's folder and asks", [scene.enter_opened("start" => "none", "code" => "y", "world" => "w1"), scene.instance_variable_get(:@entry).local.equal?(found), asked(scene)],
          [true, true, [:yes, :show_mods, :cancel]])

    # Downloads and parking with one restart.
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "personal\tvictoryscreen\tVictory Screen")
    strict.mods = "!Level Cap"
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.on_enter
    check("the offer to download names the mods turned off too", said(scene),
          "Strict needs mods that are missing or in another version here: Level Cap. Download them and restart? These mods are turned off while you play there: Invasions, Luka_Replacer and Sub.")
    $elsewhere = ["Patch/Invasions.rb"]
    elsewhere_scene = new_scene
    elsewhere_scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    $calls.clear
    elsewhere_scene.on_enter
    check("but a script it turns off behind a link to another drive keeps the game out before the download is offered",
          [said(elsewhere_scene), asked(elsewhere_scene), $calls.map(&:first) & ["mp_mods_park", "mp_restart_game", "mp_mods_restart_parked"]],
          ["1 mod script lies on another drive behind a link in Patch and cannot be turned off: Patch/Invasions.rb.", nil, []])
    $elsewhere = nil
    $calls.clear
    scene.restart_for_mods
    check("one restart installs and parks", [$parked.size, $calls.map(&:first) & ["mp_restart_game", "mp_mods_restart_parked"], $exited], [4, ["mp_mods_restart_parked"], true])
    new_session
    $parked_for = "w9"
    $recover = 2
    $ini["rejoin"] = "w9"
    Scene_Title.new.start
    $exited = false
    $calls.clear
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.restart_for_mods
    check("a restart for downloads with the same mods parked for another world parks them for this one first, the watchdog's restart keeping them",
          [$calls.map(&:first) & ["mp_mods_park", "mp_restart_game", "mp_mods_restart_parked"], $parked_for, $parked.size, $ini["rejoin"], $exited],
          [["mp_mods_park", "mp_mods_restart_parked"], "w1", 4, "w1", true])
    $ini["rejoin"] = ""
    new_session
    $ini["rejoin"] = "w1"
    Scene_Title.new.start
    $exited = false
    $calls.clear
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.restart_for_mods
    check("one with the mods parked for the world starts again through the watchdog, which hands it the journal",
          [$calls.map(&:first) & ["mp_mods_park", "mp_restart_game", "mp_mods_restart_parked"], $calls.find { |call| call[0] == "mp_mods_restart_parked" }[1],
           $parked.size, $ini["rejoin"], $exited], [["mp_mods_restart_parked"], ["w1\0", MGQ_MpModParking::REJOIN], 4, "w1", true])
    $restart_parked = 0
    $exited = false
    $calls.clear
    scene.restart_for_mods
    check("and when the watchdog cannot start, the game stays open with the mods parked and asks for a new start, since entering now would skip the downloads",
          [$calls.map(&:first) & ["mp_restart_game", "mp_mods_restart_parked"], $parked.size, $ini["rejoin"], $exited, said(scene)],
          [["mp_mods_restart_parked"], 4, "", false, "The mods were installed. Close the game and start it again to enter Strict."])
    $restart_parked = 1
    $parked_for = "w9"
    $dll["mp_mods_list"] = "state=failed\n\n"
    MGQ_MpWorldMods.forget_installed
    $calls.clear
    scene.restart_for_mods
    check("as it does when mods parked for another world cannot be claimed while the catalog is unknown, starting nothing",
          [$calls.map(&:first) & ["mp_mods_park", "mp_restart_game", "mp_mods_restart_parked"], $parked.size, $exited, said(scene)],
          [[], 4, false, "The mods were installed, but your other mods could not be turned off or kept off for Strict. Try again."])
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "personal\tvictoryscreen\tVictory Screen")
    $ini["rejoin"] = ""
    $recover = 0
    new_session

    $parked = ["Patch/Invasions.rb"]
    $parked_for = "w9"
    Scene_Title.new.start
    $park_fails = true
    $restore_fails = true
    $calls.clear
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.restart_for_mods
    check("and when the mods could not be turned off and those parked could not come back",
          [$calls.map(&:first) & ["mp_restart_game", "mp_mods_restart_parked"], $parked, $exited, said(scene)],
          [[], ["Patch/Invasions.rb"], false, "The mods were installed, but your other mods could not be turned off or kept off for Strict. Try again."])
    $calls.clear
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", world_of("", false), local, false, false))
    scene.restart_for_mods
    check("or, for a world that allows other mods, when those parked could not come back on",
          [$calls.map(&:first) & ["mp_mods_restore", "mp_restart_game", "mp_mods_restart_parked"], $parked, $exited, said(scene)],
          [["mp_mods_restore"], ["Patch/Invasions.rb"], false, "The mods were installed, but your other mods could not be turned back on for Strict. Try again."])
    $restore_fails = false
    $parked = []
    new_session
    Scene_Title.new.start
    $calls.clear
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.restart_for_mods
    check("but with none parked, it starts again for the downloads alone", [$calls.map(&:first) & ["mp_restart_game", "mp_mods_restart_parked"], $parked, $exited],
          [["mp_restart_game"], [], true])
    $park_fails = false
    $ini["rejoin"] = ""
    new_session
    $parked = []
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", world_of("!Level Cap", true, false), nil, false, false))
    asked_password = []
    scene.define_singleton_method(:ask_password) { asked_password << true }
    scene.restart_for_mods
    check("for a world this PC never entered, the lock opens first", [asked_password, $parked, $exited], [[true], [], false])
    scene.enter_opened("start" => "none", "code" => "y", "world" => "w1")
    check("then one restart installs and parks, the world's folder kept for the start after it", [$parked.size, $exited, scene.instance_variable_get(:@entry).local.equal?(found)], [4, true, true])
    strict.mods = "Level Cap; ?Luka Replacer"

    # The start after the restart.
    new_session
    $recover = 2
    $ini["rejoin"] = "w1"
    Scene_Title.new.start
    check("the start that enters the world again keeps the mods parked", [$calls.find { |call| call[0] == "mp_mods_recover" }[1], parking.holding?, $parked.size], [["w1\0"], true, 4])
    MGQ_MpWorldMods.on_title_update(Scene_Title.new)
    check("and opens the world screen to enter it", [$called, MGQ_MpWorldMods.rejoining], [Scene_MpWorlds, "w1"])
    scene = new_scene
    scene.rejoin([], "ready")
    check("a world no longer in the list puts them back and goes to the title screen", [$parked, $returned, parking.holding?, parking.restart_due?], [[], true, false, true])
    title = Scene_Title.new
    parking.on_title_update(title)
    check("which tells why", $box, ["Turning your mods back on", "The world you restarted for is not in the list right now. Your mods are back after a restart.", "The game starts again in a moment."])
    (MGQ_MpModParking::RESTART_FRAMES - 1).times { parking.on_title_update(title) }
    check("then starts the game again", [$exited, $ini[MGQ_MpModParking::RESTARTED_SETTING], parking.title_busy?], [true, "1", false])

    new_session
    $parked = ["Patch/Invasions.rb"]
    $parked_for = "w1"
    $recover = 2
    Scene_Title.new.start
    $ini["rejoin"] = ""
    MGQ_MpWorldMods.instance_variable_set(:@rejoining, "w1")
    full = world_of("Level Cap; ?Luka Replacer; Extra Mod")
    full.online = 4
    scene = new_scene
    scene.rejoin([MGQ_MpWorld::Entry.new("w1", "Strict", full, local, false, false)], "ready")
    check("a full world puts them back too", [$parked, $returned, parking.restart_due?], [[], true, true])
    new_session

    $parked = ["Patch/Invasions.rb"]
    Scene_Title.new.start
    scene = new_scene
    scene.instance_variable_set(:@rejoin_entering, true)
    scene.instance_variable_get(:@forms)[:password] = MGQ_MpWorld::Form.password("Strict")
    scene.instance_variable_set(:@form_symbol, :password)
    scene.on_form_cancel
    parking.on_title_update(title)
    check("so does backing out of the world's password, which tells no reason", [$parked, $returned, $box[1]], [[], true, "Your mods are back after a restart."])
    new_session

    $parked = ["Patch/Invasions.rb"]
    Scene_Title.new.start
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", strict, local, false, false))
    scene.instance_variable_set(:@rejoin_entering, true)
    scene.define_singleton_method(:open_box) { |_kind| }
    scene.on_show_mods
    scene.back_to_list
    check("looking at the mods ends that entry, so going back to the list later keeps them parked", [$parked.size, $returned, parking.holding?], [1, false, true])
    new_session

    # The creator's own world, whose data scan was made with the mods it turns off on.
    fingerprint = "#{MGQ_MpWorld::GameData::FORMAT}:" + MGQ_MpWorld::GameData::PARTS.map { "00000000" }.join(".")
    MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, fingerprint)
    own = world_of("Level Cap; ?Luka Replacer")
    own.strict = true
    own.data = fingerprint.sub("00000000", "11111111")
    $parked = ["Patch/Invasions.rb", "Patch/Sub/Extra-Mod.rb"]
    $parked_for = "w1"
    Scene_Title.new.start
    scene = new_scene
    scene.instance_variable_set(:@me, "creator")
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Strict", own, local, false, false))
    entered = []
    scene.define_singleton_method(:enter) { |*args| entered << args }
    scene.on_enter
    check("entering it with them turned off asks the creator to take this game's data", [said(scene), asked(scene)],
          ["The data scan of Strict was made with your other mods on. Take your game's data as it is now and enter?", [:yes, :cancel]])
    $calls.clear
    scene.on_confirmed
    $dll["mp_dir_action"] = "state=done\nkind=data\n\n"
    scene.follow_action
    check("yes sends it and enters", [$calls.map(&:first).include?("mp_dir_set_data"), own.data == fingerprint, entered.size], [true, true, 1])
    $dll["mp_dir_action"] = ""
    MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
    $parked = []
    new_session

    # Leaving the world.
    $recover = 0
    $parked = ["Patch/Invasions.rb"]
    MGQ_MpWorld.instance_variable_set(:@world, local)
    MGQ_MpWorld.instance_variable_set(:@pending, :new_game)
    Scene_Title.new.start
    check("the title screen of the world's new game keeps them parked", [$parked.size, parking.title_busy?], [1, false])
    MGQ_MpWorld.instance_variable_set(:@pending, nil)
    Scene_Title.new.start
    check("going back to the title screen puts them back, the game starting again", [$parked, MGQ_MpWorld.open?, parking.restart_due?, $calls.select { |call| call[0] == "mp_mods_restore" }.last[1]],
          [[], false, true, [1]])
    parking.on_title_update(title)
    check("and says so", $box[1], "Your mods are back after a restart.")
    $called = nil
    $ini["rejoin"] = "w2"
    MGQ_MpWorldMods.on_title_update(title)
    check("meanwhile no world is entered", [$called, $ini["rejoin"]], [nil, "w2"])
    $ini["rejoin"] = ""
    new_session

    $parked = ["Patch/Invasions.rb"]
    $restore_fails = true
    MGQ_MpWorld.instance_variable_set(:@world, local)
    Scene_Title.new.start
    check("a restore that failed only tells the player", [parking.restart_due?, (parking.on_title_update(title); $box[1])], [false, MGQ_MpModParking::NOT_BACK_TEXT])
    $saves = []
    $notices.clear
    check("after which no game is saved outside a world, and a save the player makes is told why",
          [DataManager.save_game(0), DataManager.auto_save_game, $saves, $notices], [false, false, [], [[:mod_parking, MGQ_MpModParking::SAVE_OFF_TEXT]]])
    MGQ_MpWorld.instance_variable_set(:@world, local)
    check("while saving in a world stays on", [DataManager.save_game(1), $saves], [true, [1]])
    MGQ_MpWorld.instance_variable_set(:@world, nil)
    $restore_fails = false
    $parked = []
    new_session

    Scene_Title.new.start
    $saves = []
    check("a session without parked mods saves as ever", [DataManager.save_game(2), DataManager.auto_save_game, $saves], [true, true, [2, :auto]])
    new_session
    $parked = ["Patch/Invasions.rb"]
    Scene_Title.new.start
    parking.restore
    $saves = []
    check("one that started with mods parked saves nothing once they are back either, since it still runs without them", [DataManager.save_game(2), $saves], [false, []])
    new_session

    $parked = ["Patch/Invasions.rb"]
    $conflicts = 1
    MGQ_MpWorld.instance_variable_set(:@world, local)
    Scene_Title.new.start
    check("leaving the world tells how many mods went to the conflicts folder",
          (parking.on_title_update(title); $box[1]),
          "Your mods are back after a restart. 1 of your mods went to Parked mods/Conflicts because another file took their place in Patch.")
    $conflicts = nil
    new_session

    $parked = ["Patch/Invasions.rb"]
    $parked_for = "w1"
    $log = []
    check("the parked state is read from the DLL", parking.parked_paths, ["Patch/Invasions.rb"])
    $parked_text = "error\tthe journal is locked"
    check("and the one read last stays when the DLL cannot read its journal, which is logged once",
          [parking.parked_paths, parking.parked?, $log.grep(/could not read the parked mods/).size], [["Patch/Invasions.rb"], true, 1])
    $parked_text = nil
    $parked = []
    new_session

    $parked = ["Patch/Invasions.rb"]
    $restore_held = true
    Scene_Title.new.start
    check("a game that starts while another game of this folder holds the mods says nothing", [parking.title_busy?, parking.holding?], [false, false])
    $calls.clear
    2.times { Scene_Title.new.start }
    check("nor does any later title screen without a world, which leaves them to the other game",
          [parking.title_busy?, $calls.map(&:first).include?("mp_mods_restore"), $parked.size], [false, false, 1])
    MGQ_MpWorld.instance_variable_set(:@world, local)
    Scene_Title.new.start
    check("and leaving the world says that the other game has them, starting nothing again",
          [parking.restart_due?, (parking.on_title_update(title); $box[1]), $parked.size], [false, MGQ_MpModParking::HELD_TEXT, 1])
    $restore_held = false
    $parked = []
    new_session

    # The start after a game that closed with mods parked.
    $recover = 1
    $ini[MGQ_MpModParking::RESTARTED_SETTING] = ""
    Scene_Title.new.start
    check("mods a closed game left parked come back, the game starting again", [parking.restart_due?, (parking.on_title_update(title); $box[1])], [true, MGQ_MpModParking::RECOVERED_TEXT])
    new_session
    $conflicts = 2
    Scene_Title.new.start
    check("telling how many went to the conflicts folder", (parking.on_title_update(title); $box[1]),
          "#{MGQ_MpModParking::RECOVERED_TEXT} 2 of your mods went to Parked mods/Conflicts because another file took their place in Patch.")
    $conflicts = nil
    new_session
    $ini[MGQ_MpModParking::RESTARTED_SETTING] = "1"
    Scene_Title.new.start
    check("but never twice in a row", [parking.restart_due?, parking.title_busy?, $ini[MGQ_MpModParking::RESTARTED_SETTING]], [false, true, ""])
    new_session
    $recover = -1
    Scene_Title.new.start
    check("a recovery that failed tells the player", [parking.restart_due?, (parking.on_title_update(title); $box[1])], [false, MGQ_MpModParking::NOT_BACK_TEXT])
    $buttons = [:C]
    parking.on_title_update(title)
    $buttons = []
    check("who closes the notice", [parking.title_busy?, $box], [false, nil])
    new_session
    $recover = 0
    ENV["MGQMP_OPTIONS_DUMP"] = "dump.txt"
    $calls.clear
    Scene_Title.new.start
    check("a game the World Admin tool started for the options touches nothing", $calls.map(&:first).grep(/mp_mods/), [])
    ENV.delete("MGQMP_OPTIONS_DUMP")
    new_session

    # The update.
    $parked = ["Patch/Invasions.rb"]
    MGQ_MpWorld::UpdateOffer.instance_variable_set(:@box, Sprite_MpMessageBox.new)
    $update_answer = 0
    MGQ_MpWorld::UpdateOffer.update_and_install
    check("an updater that could not start leaves the mods parked and the game open", [$parked, $exited, $box[1]],
          [["Patch/Invasions.rb"], false, MGQ_MpWorld::UpdateOffer::FAILED_TEXT])
    $update_answer = nil
    MGQ_MpWorld::UpdateOffer.update_and_install
    check("one that started puts them back before the game closes for it", [$parked, $exited], [[], true])
    new_session

    # The relay's word that the open world now turns other mods off.
    route = MGQ_MpOverworldSync.routes[MGQ_MpOverworldSync::MODS_RULE_FIELD]
    MGQ_MpWorld.instance_variable_set(:@world, local)
    MGQ_MpWorldMods.enter_world(strict, "me")
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap")
    check("a push not from the relay is ignored", parking.instance_variable_get(:@kick), nil)
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "0", "mods" => "Level Cap; Invasions", :relay => true)
    check("a world that allows other mods now only takes its mods", [parking.instance_variable_get(:@kick), MGQ_MpWorldMods.instance_variable_get(:@world)[:mods]], [nil, "Level Cap; Invasions"])
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap; Invasions; Sub; Luka Replacer", :relay => true)
    check("one that turns them off while the player has none on leaves the player in it", parking.instance_variable_get(:@kick), nil)
    $elsewhere = ["Patch/Invasions.rb"]
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap; Sub; Luka Replacer", :relay => true)
    check("a script it turns off behind a link to another drive counts as on, since it is never parked", parking.instance_variable_get(:@kick).nil?, false)
    parking.instance_variable_set(:@kick, nil)
    $elsewhere = nil
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap", :relay => true)
    $map_free = false
    $scene = Scene_Map.new
    $notices.clear
    MGQ_MpModParking::KICK_FRAMES.times { parking.tick }
    check("one that turns the player's mods off tells the player, and waits for the map to be free", [$notices, $went], [[[:mod_parking, "Strict now turns off other mods. Enter it again to play."]], nil])
    $map_free = true
    parking.tick
    check("then goes to the title screen, which tells it again", [$went, $faded, parking.title_busy?], [Scene_Title, true, true])
    new_session

    $parked = ["Patch/Sub/Extra-Mod.rb"]
    $parked_for = "w1"
    MGQ_MpWorld.instance_variable_set(:@world, local)
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap", :relay => true)
    (MGQ_MpModParking::KICK_FRAMES + 1).times { parking.tick }
    Scene_Title.new.start
    parking.on_title_update(title)
    check("with mods parked too, the title screen tells why before it starts the game again for them",
          [$parked, $box[1]], [[], "Strict now turns off other mods. Enter it again to play. Your mods are back after a restart."])
    new_session

    online = MGQ_MpWorld::World.new("abcdef", "code" => "x", "name" => "Strict", "world" => "w1")
    MGQ_MpWorld.instance_variable_set(:@world, online)
    $dll["mp_mods_list"] = "state=failed\n\n"
    MGQ_MpWorldMods.forget_installed
    route.call(nil, MGQ_MpOverworldSync::MODS_RULE_FIELD => "1", "mods" => "Level Cap", :relay => true)
    check("while the catalog is unknown the player stays in the world", parking.instance_variable_get(:@kick), nil)
    catalog("personal\tvictoryscreen\tVictory Screen")
    $calls.clear
    (MGQ_MpModParking::RECHECK_STEP * 2).times { parking.tick }
    check("and is checked again with the list and catalog fetched for it", [$calls.map(&:first).include?("mp_dir_refresh"), parking.instance_variable_get(:@kick).nil?], [true, false])
    new_session

    MGQ_MpWorld.instance_variable_set(:@world, online)
    parking.entered
    (MGQ_MpModParking::RECHECK_STEP * 2).times { parking.tick }
    check("a world entered from an older list is checked against one fetched after entering", parking.instance_variable_get(:@kick).nil?, false)
    new_session
    MGQ_MpWorld.instance_variable_set(:@world, nil)
    $scene = nil
  end
end
