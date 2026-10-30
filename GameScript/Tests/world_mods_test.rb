#----------------------------------------------------------------
#  world_mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Checked the game data measured again and compared once the world's mods loaded, and the warning of a difference
#                            - Checked that the Mod Framework's options lock the options a world sets
#                            - Checked the session of a world that turns other mods off and the restart once its rule turns off a mod that runs
#                            - Stopped loading the deleted world_mods_parking.rbx
#                            - Checked the install of a world's mods through the Mod Framework and the entry again after its restart
#      Paulinchen  2026-10-23: Left what an edit says of the shared settings and which settings it changes to the DLL's tests
#                            - Checked that the screen plays the DLL's steps of the download offer and the entry after a restart
#                            - Read the list box's lines through the stand-ins of the world screen's model
#                            - Dropped the stand-in of the deleted mp_mods_recover
#                            - Left the checks of the shared settings' rules, sending and notices to the DLL's tests and checked the steps this script plays
#                            - Left the checks of the catalog, the hashes and the options to send to the DLL's tests and answered the mods check through the bridge
#                            - Opened the world screen's forms through the DLL
#                            - Answered the mod catalog through the bridge
#                            - Answered the mod keys and the scripts in Patch through the bridge
#                            - Dropped the restart by hand under Wine
#                            - Dropped the checks of the deleted options dump
#      Paulinchen  2026-10-22: Measured the settings and the creator's hashes against the relay's limits as the script names them
#                            - Stood in for the update message
#      Paulinchen  2026-10-15: Checked the world's mods and options this game hands the battle server
#      Paulinchen  2026-10-13: Kept the title screen from writing GameData.ini
#      Paulinchen  2026-10-12: Followed the settings to their own Mod Config group and checked the dump leaves the hotkeys out
#                            - Stood in for Ini.load and the favourites and hidden worlds in Player.ini
#      Paulinchen  2026-10-11: Stood in for the game's frame
#      Paulinchen  2026-10-09: Loaded world_mods_parking.rbx
#      Paulinchen  2026-10-08: Covered the marker, the Shared Mod Settings row, the creator's options and the options dump
#                            - Covered the settings the relay took last, the notices and the edit form's texts
#                            - Removed the checks of the creator's button
#                            - Covered settings applied only for options a world may set and the restart under Wine
#                            - Let the DLL stand-in hold a started action as busy
#      Paulinchen  2026-10-07: Covered the options sent from a copy of an older or unknown version
#                            - Looked DLL signatures up in the export table of Multiplayer.rb
#      Paulinchen  2026-10-06: Expected the summary to name missing mods and mods in another version
#                            - Told whether a small window of the world screen takes input
#                            - Covered the catalog while the list loads, options with :values and the settings' length limit
#                            - Refused a DLL call whose arguments differ from its signature
#                            - Covered the Mod Config options an admin's game sends
#                            - Covered the creator's button in Mod Config and the unlocked options
#                            - Covered a load_game a translation plugin replaced
#                            - Covered a link to a zip of a release
#                            - Created
#
#----------------------------------------------------------------

# Checks a world's required mods (world_mods.rbx, world_screen.rbx): the relay's mod catalog, a
# game's copies against it and against the creator's hashes, the offer to download and restart,
# entering the world again afterwards, the mod settings a world shares while in it, and the options
# dump for the World Admin tool.


require_relative "support"
require_relative "rules_support"
require "zlib"

# Stand-ins for the game.

# The game's scene base: returning to the last scene sets $returned.
class Scene_Base; def return_scene; $returned = true; end; def update; end; end
# The game's base of menu scenes.
class Scene_MenuBase < Scene_Base; end
# The game's load screen.
class Scene_Load < Scene_Base; end
# The game's window base, which draws nothing.
class Window_Base; def initialize(*); end; end
# The game's window with a cursor.
class Window_Selectable < Window_Base; end
# The game's command window.
class Window_Command < Window_Selectable; end
# The game's name box of its text screen.
class Window_NameEdit < Window_Base; end
# The game's letter table of its text screen.
class Window_NameInput < Window_Selectable; end
# The game's color, which keeps nothing.
class Color; def initialize(*); end; end
# The game's sprite, which draws nothing.
class Sprite; def initialize(*); end; end
# The game's screen, whose frames pass at once.
module Graphics; def self.update; end; end
# The game's rectangle.
Rect = Struct.new(:x, :y, :width, :height)
# The game's title screen, which does nothing.
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; def scene_changing?; false; end; end
# The title screen's commands, which list nothing.
class Window_TitleCommand; def make_command_list; end; end
# The game's system sounds: each one played is added to $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
# The game's input: the buttons in $buttons are pressed this frame.
module Input; def self.trigger?(button); ($buttons || []).include?(button); end; end
# The game's scene manager: records the scene called and the exit, and hands out $scene or a scene
# that takes any preparation.
module SceneManager
  # Records the scene called in $called.
  def self.call(scene); $called = scene; end
  # Records the game's exit in $exited.
  def self.exit; $exited = true; end
  # The scene in $scene, or one that takes any preparation.
  def self.scene; $scene || Object.new.tap { |scene| def scene.prepare(*); end }; end
end
# The game's Mod Config screen.
class Scene_Config; end
# The game's data manager: a load sets $loaded and a new game $new_game.
module DataManager
  # Saves nothing.
  def self.save_system; end
  # Loads a save as the game does, a failure answered with false.
  def self.load_game(index); load_game_without_rescue(index) rescue false; end
  # Records the load in $loaded.
  def self.load_game_without_rescue(_index); $loaded = true; end
  # Records the new game in $new_game.
  def self.setup_new_game; $new_game = true; end
end
# The game's system data, as far as Mod Config's values.
GameSystem = Struct.new(:conf)
$game_system = GameSystem.new({})

# The options mods offer in Mod Config Remake, and its lock.
module NWConst
  # Mod Config's options.
  module Config
    # The options' defaults.
    DEFAULT = { :mod_level_cap => 1, :mod_level_cap_limits => 1 }
    # The values each option offers.
    DATA = { :mod_level_cap => [1, 0] }
    # The names of the options' values.
    DATA_TEXT = { :mod_level_cap => { 1 => { :name => "On" }, 0 => { :name => "Off" } } }
    # The rows mods add: shared, personal, hotkey, global and Return rows, and options with :values.
    MOD_CONTENTS = [
      { :key => :mod_level_cap, :name => "[Level Cap] Level Cap", :sub => true },
      { :key => :mod_level_cap_limits, :name => "     -> Job and Race Limits", :sub => true },
      { :key => :mod_level_cap_look, :name => "   Window Colour", :sub => true, :personal => true },
      { :key => :mod_party_sheet_hotkey, :name => "[Party Sheet] Hotkey", :sub => true, :keybind => true },
      { :key => :mod_party_sheet_theme, :name => "[Party Sheet] Theme", :sub => true },
      { :key => :mod_party_sheet_write, :name => "     -> Write Party Sheet", :sub => false },
      { :key => :mod_party_sheet_size, :name => "     -> Size", :sub => true, :values => lambda { [2, 4] } },
      { :key => :tab_opt, :name => "[Tab\tMod] Opt\tion", :sub => true, :values => [1, 2] },
      { :key => :mod_mp_backline, :name => "[MGQ Online Settings] PvP Backline", :sub => true },
      { :key => :mp_key_chat, :name => "[MGQ Online Hotkeys] Chat", :keybind => true },
      { :key => :global_thing, :name => "Global Thing", :sub => true },
      { :key => :return, :name => "Return", :sub => false },
    ]
  end
end
# Mod Config Remake's lock: the options a world sets.
module ModConfigRemake
  # The keys of the options a world sets, which the player cannot change.
  class << self; attr_accessor :world_keys; end
end

# Stand-ins for the world room, which keep what is told and who takes what, and for the
# notification box, which keeps its messages in the order posted.
$told = []
$notices = []
# The world room: keeps the routes and state fields, records sends in $told.
module MGQ_MpOverworldSync
  @routes = {}
  @fields = []
  # The handlers by field, the state fields' blocks and the handler of a player leaving.
  class << self; attr_reader :routes, :fields, :leave; end
  # Keeps a field's handler.
  def self.route(field, &handler); @routes[field] = handler; end
  # Takes no observer.
  def self.on_observe(&_block); end
  # Keeps the handler of a player leaving.
  def self.on_leave(&block); @leave = block; end
  # Keeps a block of state fields.
  def self.state_fields(&block); @fields << block; end
  # Records a send in $told, failing while $tell_fails.
  def self.tell(seat, fields, body = ""); $told << [seat, fields, body] unless $tell_fails; !$tell_fails; end
  # Names a player for the log.
  def self.who(peer); peer ? peer.state["name"] : "nobody"; end
  # Another player: their seat and their state.
  module Peers; Peer = Struct.new(:seat, :state); end
  # The field of the relay's push of the world's mods rule.
  MODS_RULE_FIELD = "mods_rule_value"
  # The map is free while $map_busy is not set.
  def self.map_free?; !$map_busy; end
end
# The notification box: keeps its notices in $notices.
module MGQ_MpNotices
  # Posts a notice under its key, in place of the key's earlier one.
  def self.message(key, text, _frames = 180); drop(key); $notices << [key, text]; end
  # Takes a key's notice down.
  def self.drop(key, _reason = ""); $notices.reject! { |known, _| known == key }; end
end

# What the notification box shows, its lines joined.
#
# @return [String] The text.
def shown
  $notices.reverse.map { |_, text| text }.join(" ")
end

# Lets the notices posted so far grow old, as the frames they show for pass.
def wait_out_notices
  MGQ_MpWorldMods::NOTICE_FRAMES.times { MGQ_MpWorldMods.tick }
end

# Tells whether the notification box shows a notice whole, in lines that fit it.
#
# @return [Array(Boolean, Boolean)] Whether it has at most NOTICE_LINES lines of at most
#   NOTICE_LINE_CHARS characters, and whether none is cut.
def fits
  [$notices.size <= MGQ_MpWorldMods::NOTICE_LINES && $notices.all? { |_, text| text.size <= MGQ_MpWorldMods::NOTICE_LINE_CHARS }, $notices.none? { |_, text| text.end_with?("...") }]
end

# Stand-ins for the mod's base script and its DLL.
$sounds = []
$calls = []
$dll = {}
$restart = 1
$ini = {}
# The mod's base script: always available, never outdated, with a player named Me whose Player.ini
# lives in $ini.
module MGQ_Multiplayer
  # How the mod loads, all of it at once here: the action after a restart that enters a world again.
  module Stages
    REJOIN_ACTION = "multiplayer.rejoin"
    def self.staged?; false; end
    def self.enter(_reason); false; end
    def self.when_loaded(_tag); yield; end
  end
  # The message of an update.
  UPDATE_MESSAGE = "Update."
  # Gives the update message as it is.
  def self.update_message; UPDATE_MESSAGE; end
  # The DLL is always there.
  def self.available?; true; end
  # The game is never outdated.
  def self.outdated?; false; end
  # Leaves a text as it is.
  def self.clean(text); text; end
  # Leaves a path as it is.
  def self.path(name); name; end
  # The mod's log, kept in $log.
  module Log; def self.write(message); ($log ||= []) << message; end; end
  # The player Me, whose settings live in $ini.
  module Player
    # Shares nothing.
    def self.share; end
    # The player's name.
    def self.name; "Me"; end
    # A setting of Player.ini.
    def self.setting(key); $ini[key]; end
    # Stores a setting in Player.ini.
    def self.store(key, value); $ini[key] = value.to_s; end
    # No setting lies under any prefix.
    def self.keys_under(_prefix); []; end
  end
  # An ini file reader that reads every file as empty.
  module Ini; def self.read(_path); {}; end; def self.load(_path, _quiet = false); {}; end; end
  # The link to the DLL: records each call in $calls and reads its values from $dll.
  module Link
    # A DLL function: a call is checked against its signature, recorded and answered as the DLL would.
    Function = Struct.new(:name, :signature) do
      # Calls the function: mp_restart_game answers $restart, and the functions in $refused answer 0.
      #
      # @param args [Array] The call's arguments.
      # @return [Integer] The DLL's answer.
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, signature, args]
        case name
        when "mp_restart_game" then $restart
        when "mp_dir_clear"
          $dll["mp_dir_action"] = ""
          1
        else
          refused = ($refused || []).include?(name)
          # The DLL holds the action it started as busy until it ends.
          $dll["mp_dir_action"] = "state=busy\nkind=settings\n\n" if name == "mp_dir_set_settings" && !refused
          refused ? 0 : 1
        end
      end
    end
    # A DLL function with its signature from the export table of Multiplayer.rb.
    def self.function(name); Function.new(name, dll_signature(name)); end
    # The DLL's value of a name, from $dll.
    def self.read(name, _size); $dll[name].to_s; end
    # Opens no world.
    def self.open(_code); end
    # Closes nothing.
    def self.close; end
    # Reads a DLL answer: its name=value lines up to a blank line, and the rest as :payload.
    #
    # @param text [String] The answer.
    # @return [Hash] The values by name, and the payload under :payload.
    def self.parse(text)
      head, payload = text.split("\n\n", 2)
      state = { :payload => payload.to_s }
      head.to_s.split("\n").each { |line| k, v = line.split("=", 2); state[k] = v if v }
      state
    end
  end
end

load_script "world_save_distribution"
load_script "core_hotkeys"
load_script "ui"
load_script "ui_text_box"
load_script "world"
load_script "world_mods"
load_script "world_text"
load_script "world_screen"
open_rules_bridge
# GameData.ini, which the title screen writes, is world_data_test.rb's; this game has no database to read.
MGQ_MpWorld::GameData.instance_variable_set(:@written, true)

# A small window of the world screen: keeps the commands it opened with.
class FakeChoice
  # The commands it opened with last, nil while closed.
  attr_reader :choices
  # Opens with commands.
  def start(choices); @choices = choices; end
  # Closes.
  def finish; @choices = nil; end
  # Takes input.
  def activate; end
  # Takes no input.
  def deactivate; end
  # Takes the cursor off.
  def unselect; end
  # Whether it is open and takes input.
  def active; !@choices.nil?; end
  # The cursor's row, -1 for none.
  def index; -1; end
end

# The lines at the top of the world screen: keeps what they show.
class FakeInfo
  # What they show.
  attr_reader :lines
  # Shows lines.
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
  scene
end

# What the lines at the top of the world screen say, the player's name left out.
#
# @param scene [Scene_MpWorlds] The world screen.
# @return [String] The message.
def said(scene)
  scene.instance_variable_get(:@info_window).lines[1]
end

# Hands the mods module a catalog and forgets what it read before.
#
# @param lines [Array<String>] The catalog's lines, see catalog_told.
def catalog(*lines)
  catalog_told("ready", *lines)
  MGQ_MpWorldMods.forget_installed
end

mods = MGQ_MpWorldMods
listed = MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, "creator", 0, "Creator", "Modded", "none", [], false, false, true, false, false, "", "", "", "", "")

# The world screen: the offer to download. The DLL checks the mods (ModCheck, covered by its own
# tests) and answers with the rows it found.
checked = []
level_cap = { "name" => "Level Cap", "yours" => "1.3.5", "worlds" => "1.4.0", "key" => "levelcap", "target" => "Patch/Mods/Level Cap.rb",
              "text" => "Level Cap: yours 1.3.5, the world's 1.4.0", "downloadable" => true }
other_mod = { "name" => "Other Mod", "yours" => "differs", "worlds" => nil, "key" => nil, "target" => nil,
              "text" => "Other Mod: yours differs from the world creator's copy", "downloadable" => false }
listed.mods = "!Level Cap"
listed.mod_hashes = "Other Mod=#{'e' * 64}"
$mod_check = lambda do |request|
  checked << request
  { "known" => true, "rows" => [level_cap], "summary" => "Modded needs mods that are missing or in another version here: Level Cap. Download them?" }
end
offer = "Modded needs mods that are missing or in another version here: Level Cap. Download them?"
scene = new_scene
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false))
$screen_steps = [["say", offer], ["confirm", "mods", [["Download", "yes"], ["See the mods", "show_mods"], ["Back", "cancel"]]]]
scene.on_enter
check("the DLL's steps offer to download the mods, to see them, or to go back", [said(scene), scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }], [offer, [:yes, :show_mods, :cancel]])

# The Mod Framework installs the mods: one of the game's mods is installed already, the world's
# is one it finds on the website.
module Mod_Framework
  module Mods
    class << self
      attr_accessor :installing, :restarted
      def state; { "mods" => [{ "name" => "Party_Sheet", "title" => "Party Sheet", "id" => "site:party-sheet" }] }; end
      def check(saved); [{ "kind" => "install", "name" => saved[0][0], "target" => "site:level-cap" }]; end
      def install(ids, &done); @installing = [ids, done]; true; end
      def loaded; ["Level_Cap"]; end
      def restart(_reason, action, value); @restarted = [action, value]; :restarting; end
    end
  end
end
$installed_forgotten = 0
MGQ_MpWorldMods.singleton_class.send(:alias_method, :tested_forget_installed, :forget_installed)
MGQ_MpWorldMods.define_singleton_method(:forget_installed) { $installed_forgotten += 1; tested_forget_installed }
$screen_steps = [["install", [["Level Cap", "levelcap"]]]]
scene.on_confirmed
ids, done = Mod_Framework::Mods.installing
check("download hands the framework the mod by the id it finds for it, holding the screen meanwhile",
      [screen_requests("screen.answer").last, ids, scene.instance_variable_get(:@busy)], [{ "answer" => "yes" }, ["site:level-cap"], "mods"])
check("an installed mod goes by the framework's id of it", MGQ_MpWorldMods.framework_id("Party Sheet", "partysheet"), "site:party-sheet")
$screen_steps = [["forget_installed"], ["restart", "w1"]]
done.call(["Level_Cap"], nil)
check("once installed the DLL hears it, a mod installed running already, and the scripts forget what Patch held",
      [screen_requests("screen.answer").last, $installed_forgotten], [{ "answer" => "installed", "ok" => true, "text" => nil, "restart" => true }, 1])
check("the framework then starts the game again to enter the world", Mod_Framework::Mods.restarted, ["multiplayer.rejoin", "w1"])

# A mod only its author has.
listed.mods = "!Other Mod"
$mod_check = lambda { |_request| { "known" => true, "rows" => [other_mod], "summary" => "Modded needs mods that are missing or in another version here: Other Mod (get it from its author)." } }
scene = new_scene
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false))
$sounds.clear
$screen_steps = [["buzz"], ["say", "Modded needs mods that are missing or in another version here: Other Mod (get it from its author)."], ["confirm", "mods", [["See the mods", "show_mods"], ["Back", "cancel"]]]]
scene.on_enter
check("a mod the relay cannot give is named, with no download", [said(scene), scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }, $sounds],
      ["Modded needs mods that are missing or in another version here: Other Mod (get it from its author).", [:show_mods, :cancel], ["buzzer"]])
scene.instance_variable_set(:@list_box, Object.new)
scene.on_show_mods
check("seeing the mods tells the DLL, which ends an entry after a restart", screen_requests("screen.answer").last, { "answer" => "show_mods" })
check("the mods box shows the difference", screen_detail.mod_lines(listed.mods, nil, mods.differing(listed)), [[:head, "Mods (1)"], [:item, "Other Mod", :gold, "required, yours differs from the world creator's copy"]])
$mod_check = nil
listed.mod_hashes = ""

# Entering again after the restart the Mod Framework made for a world's mods.
mods.restarted_for("w1")
$called = nil
title = Scene_Title.new
mods.on_title_update(title)
check("the title screen opens the world screen once to enter the world again", [$called, mods.rejoining, mods.take_rejoin], [Scene_MpWorlds, "w1", nil])
scene = new_scene
scene.instance_variable_set(:@me, "me")
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, "1:x")
scene.open_steps
MGQ_MpWorld::GameData.instance_variable_set(:@fingerprint, nil)
check("the world screen hands the DLL the world to enter again, which it enters once the list holds it", [screen_requests("screen.do").last["rejoin"], mods.rejoining], ["w1", nil])

# A world that turns other mods off: the Mod Framework enters the game with the mods of its session.
entered = []
sessions = []
MGQ_Multiplayer::Stages.define_singleton_method(:staged?) { true }
MGQ_Multiplayer::Stages.define_singleton_method(:enter) { |reason, only = nil| entered << [reason, only]; true }
Mod_Framework::Mods.define_singleton_method(:plan) { { "load" => [["Multiplayer", "Title"], ["Level_Cap", "Regular"], ["Invasions", "Regular"]] } }
Mod_Framework::Mods.define_singleton_method(:stays_on) { ["Wide_Text"] }
$world_bridge.answer("mods.session") { |request| sessions << request; { "only" => ["Multiplayer", "Level_Cap"], "off" => ["Invasions"], "text" => "Strict plays without your other mods." } }
data_checks = []
$data_warning = nil
MGQ_MpWorld::GameData.define_singleton_method(:measure_entered) { "2:with the world's mods" }
$world_bridge.answer("worlds.data_check") { |request| data_checks << request; $data_warning }
strict = listed.dup
strict.name = "Strict"
strict.mods = "!Level Cap"
strict.other_mods_off = true
$notices.clear
mods.note_session(strict)
check("the world screen only notes the mods of the session", [entered, $notices], [[], []])
handed = lambda { ($settings_calls || []).count { |name, _| name == "settings.options" } }
before = handed.call
mods.enter_game
check("a world that turns other mods off enters with only the mods of its session, and the player hears which stay off",
      [entered.last, sessions.last.values_at("world", "mods", "names", "stays_on"), $notices.last],
      [["the world Strict", ["Multiplayer", "Level_Cap"]], ["Strict", "!Level Cap", ["Multiplayer", "Level_Cap", "Invasions"], ["Wide_Text"]], [:world_mods_off, "Strict plays without your other mods."]])
check("then the DLL takes the options again, those of the mods that loaded among them", handed.call, before + 1)
mods.enter_game
check("and the world enters once", entered.size, 1)
loose = listed.dup
loose.other_mods_off = false
mods.note_session(loose)
mods.enter_game
check("a world that allows other mods enters with every mod that is on", [entered.last, sessions.size], [["the world Modded", nil], 1])
check("each entry has the DLL compare the game data, measured again once the world's mods loaded, with the world's",
      [data_checks.size, data_checks.last], [2, { "world" => loose.id, "data" => "2:with the world's mods" }])
$data_warning = "Your game differs from the creator's of Modded. Some things may not work as in their game."
$notices.clear
mods.note_session(loose)
mods.enter_game
check("a game whose data differs reads why in the notification box and plays on", $notices, [[:world_data_differs, $data_warning]])
$data_warning = nil
MGQ_Multiplayer::Stages.define_singleton_method(:staged?) { false }
mods.note_session(loose)
mods.enter_game
check("so does one without the Mod Framework, whose mods all loaded at the start", data_checks.size, 4)
MGQ_Multiplayer::Stages.define_singleton_method(:staged?) { true }

# Its creator turns other mods off while the player is in it: a mod the session runs that it now
# turns off starts the game again into the world, once the player was told and the map is free.
nows = []
Mod_Framework::Mods.define_singleton_method(:loaded) { ["Multiplayer", "Invasions", "Wide_Text"] }
# Once entered, every mod that loaded runs until the game starts again.
Mod_Framework::Mods.define_singleton_method(:stays_on) { ["Multiplayer", "Invasions", "Wide_Text"] }
$world_bridge.answer("mods.now_off") { |request| nows << request; { "off" => ["Invasions"], "text" => "Strict now turns off other mods." } }
MGQ_MpWorld.instance_variable_set(:@world, Struct.new(:directory_id, :name).new("w1", "Strict"))
Mod_Framework::Mods.restarted = nil
mods.rule_pushed({ "mods_rule_value" => "1", "mods" => "!Level Cap" })
check("a push not from the relay is left alone", nows, [])
mods.rule_pushed({ "mods_rule_value" => "1", "mods" => "!Level Cap", :relay => true })
check("the relay's push asks which mods the session runs that the world turns off now", nows.last.values_at("world", "off", "mods", "running"), ["Strict", true, "!Level Cap", ["Multiplayer", "Invasions"]])
$map_busy = true
(mods::KICK_FRAMES + 1).times { mods.follow_kick }
check("the player is told, and the game waits while the map is busy", [$notices.last, Mod_Framework::Mods.restarted], [[:world_mods_off, "Strict now turns off other mods."], nil])
$map_busy = false
mods.follow_kick
check("then starts again into the world", Mod_Framework::Mods.restarted, ["multiplayer.rejoin", "w1"])
MGQ_MpWorld.instance_variable_set(:@world, nil)
MGQ_Multiplayer::Stages.define_singleton_method(:staged?) { false }

# The settings a world shares. The DLL decides which hold, sends them and words the notices
# (SharedSettingsSync, covered by its own tests); this script hands it the creator's options and
# plays its steps.
$game_system.conf = { :mod_level_cap => 0, :mod_party_sheet_theme => :dark, :mod_party_sheet_hotkey => 0x51, :global_thing => 5 }
check("values keep their type, and semicolons and equal signs survive", ["i:-3", "f:1.5", "b:true", "b:false", "y:dark", mods.encode("a;b=c%")].map { |text| mods.decode(text) },
      [[true, -3], [true, 1.5], [true, true], [true, false], [true, :dark], [true, "a;b=c%"]])
check("a large decimal as Ruby writes it survives", mods.decode(mods.encode(1.0e20)), [true, 1.0e20])
check("an unknown type is left out", [mods.decode("x:1"), mods.encode([1])], [[false, nil], nil])
check("the marker is no option", mods.settings_from("@shared=o:1;mod_level_cap=i:0;broken"), { :mod_level_cap => 0 })

module MGQ_MpWorld; def self.open?; $world_open; end; end
row_key = MGQ_MpWorldMods::SHARED_OPTION
# The row of Shared Mod Settings in Mod Config.
row = lambda { NWConst::Config::MOD_CONTENTS.find { |entry| entry[:key] == row_key } }
creator = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "creator", "name" => "Creator", "mod_settings" => "abc" })
# A listed world with Level Cap and Party Sheet, of a creator and with mod settings.
world = lambda { |creator_id, settings| MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, creator_id, 0, "Creator", "Modded", "none", [], false, false, true, false, false, "", "!Level Cap; Party Sheet", "", "", settings) }
# The request of the last call of a settings topic.
asked = lambda { |topic| found = $settings_calls.reverse.find { |name, _| name == topic }; found && found[1] }
shared = "@shared=o:1;mod_level_cap=i:0;mod_party_sheet_theme=y:dark;mod_party_sheet_hotkey=i:7;global_thing=i:9;mod_level_cap_look=i:3;mod_missing=i:7"

check("the details say what the DLL says of a world's settings", [mods.details_text(world.call("creator", "@shared=o:1"), "me"), asked.call("settings.details")],
      ["Mod settings: shared", { "settings" => "@shared=o:1", "creator_id" => "creator", "creator_name" => "Creator", "me" => "me" }])
check("handing it this game's Mod Config groups once, each option's key, its name as its row shows it and the names of its values",
      asked.call("settings.options").map { |name, options| [name, options.first] },
      [["Level Cap", ["mod_level_cap", "Level Cap", [["i:1", "On"], ["i:0", "Off"]]]], ["Party Sheet", ["mod_party_sheet_hotkey", "Hotkey", []]], ["Tab\tMod", ["tab_opt", "Opt\tion", []]],
       ["MGQ Online Settings", ["mod_mp_backline", "PvP Backline", []]], ["MGQ Online Hotkeys", ["mp_key_chat", "Chat", []]]])
Scene_Title.new.start
$world_open = true
check("outside a world Mod Config has no row of Shared Mod Settings", row.call, nil)
mods.enter_world(world.call("creator", shared), "me")
check("entering a world hands the DLL the world as the list has it", asked.call("settings.enter"),
      { "world" => { "id" => "w1", "name" => "Modded", "creator_id" => "creator", "creator_name" => "Creator", "mods" => "!Level Cap; Party Sheet", "settings" => shared }, "me" => "me", "fresh" => true })
check("and adds the row to the group of Monster Girl Quest! Online's settings, personal, with On and Off",
      [row.call[:name], row.call[:sub], row.call[:personal], NWConst::Config::DATA[row_key], NWConst::Config::DATA_TEXT[row_key].map { |value, text| [value, text[:name]] }, NWConst::Config::MOD_CONTENTS.last[:key]],
      ["[MGQ Online Settings] Shared Mod Settings", true, true, [1, 0], [[1, "On"], [0, "Off"]], :return])
$game_system.conf = { :mod_level_cap => 1, :mod_party_sheet_theme => :light, :mod_party_sheet_hotkey => 0x51, :global_thing => 5, :mod_level_cap_look => 1 }
ModConfigRemake.world_keys = nil
DataManager.load_game(1)
check("a save loaded in the world takes its settings, and Mod Config Remake shows them as set by the world",
      [$game_system.conf[:mod_level_cap], $game_system.conf[:mod_party_sheet_theme], ModConfigRemake.world_keys], [0, :dark, [:mod_level_cap, :mod_party_sheet_theme]])
check("but none of a mod the player lacks, of the game's own options, of a key binding or of an option marked personal",
      [$game_system.conf[:mod_party_sheet_hotkey], $game_system.conf[:global_thing], $game_system.conf[:mod_level_cap_look], $game_system.conf.key?(:mod_missing)], [0x51, 5, 1, false])
check("and the DLL hears which options were set, and no creator's options from another player", asked.call("settings.loaded"),
      { "pairs" => [], "known" => [], "applied" => ["mod_level_cap", "mod_party_sheet_theme"] })
$loaded = nil
DataManager.singleton_class.send(:alias_method, :plugin_load_game, :load_game)
DataManager.define_singleton_method(:load_game) { |index| load_game_without_rescue(index) }
ModConfigRemake.world_keys = nil
DataManager.load_game(1)
check("a load_game a translation plugin replaced still takes the world's settings", [$loaded, ModConfigRemake.world_keys], [true, [:mod_level_cap, :mod_party_sheet_theme]])
DataManager.singleton_class.send(:alias_method, :load_game, :plugin_load_game)
ModConfigRemake.world_keys = nil
DataManager.setup_new_game
check("so does a new game in a world", ModConfigRemake.world_keys, [:mod_level_cap, :mod_party_sheet_theme])

$notices.clear
$settings_steps << [["notify", ["Creator shares mod settings here: 2 options", "of Level Cap and Party Sheet are set for you."]], ["row", true]]
mods.on_observe(creator)
check("another player's state goes to the DLL only in their own world", asked.call("settings.observe"), nil)
mods.take(MGQ_Multiplayer::Bridge.call("settings.step"))
check("a notice of the DLL shows in its lines, the row shows what it tells", [$notices.sort_by { |key, _| key[1] }.map(&:last), $game_system.conf[row_key]],
      [["Creator shares mod settings here: 2 options", "of Level Cap and Party Sheet are set for you."], 1])
MGQ_MpOverworldSync.routes["world_mods"].call(creator, { "world_mods" => "abc", :payload => "@shared=o:1;mod_level_cap=i:1" })
check("settings the creator tells live go to the DLL with who sent them", asked.call("settings.live"), { "sender" => "creator", "name" => "Creator", "text" => "@shared=o:1;mod_level_cap=i:1" })
$settings_steps << [["apply_live", "@shared=o:1;mod_level_cap=i:1"]]
mods.take(MGQ_Multiplayer::Bridge.call("settings.step"))
check("they apply at once, and the DLL hears which options were set", [$game_system.conf[:mod_level_cap], asked.call("settings.applied")], [1, { "keys" => ["mod_level_cap"] }])
$settings_steps << [["unlock"]]
mods.take(MGQ_Multiplayer::Bridge.call("settings.step"))
check("once the world no longer shares them, the locks are lifted and the values stay", [ModConfigRemake.world_keys, $game_system.conf[:mod_level_cap]], [[], 1])
check("the player's state tells the checksum of the settings the DLL holds", MGQ_MpOverworldSync.fields.map { |fields| fields.call }.inject({}) { |all, fields| all.merge(fields) }["mod_settings"],
      Zlib.crc32(shared).to_s(16))
MGQ_MpOverworldSync.leave.call(creator)
check("a player who leaves is forgotten by the DLL", asked.call("settings.leave"), 2)
Scene_Title.new.start
check("the title screen takes the row away and lets every option be changed again", [row.call, ModConfigRemake.world_keys, asked.call("settings.forget")], [nil, [], nil])

# The creator's own world.
mods.enter_world(world.call("me", "@shared=o:1;mod_level_cap=i:1"), "me")
check("the creator may change the row, whose help says what it does to the others", [row.call[:enable].call, row.call[:help].call.start_with?("Whether every player in this world plays with your options")], [true, true])
$game_system.conf = { :mod_level_cap => 0, :mod_level_cap_limits => 1, :mod_party_sheet_theme => :dark }
DataManager.load_game(1)
check("loading in their own world applies its settings and hands the DLL their options of the world's mods, no key bindings, buttons or personal ones, and every option this game has",
      [asked.call("settings.loaded")["pairs"], asked.call("settings.loaded")["known"].size],
      [[["mod_level_cap", "mod_level_cap=i:1"], ["mod_level_cap_limits", "mod_level_cap_limits=i:1"], ["mod_party_sheet_theme", "mod_party_sheet_theme=y:dark"]], NWConst::Config::MOD_CONTENTS.size])
check("and leaves their options unlocked", ModConfigRemake.world_keys, [])
$settings_calls.clear
$scene = Scene_Config.new
Scene_Base.new.update
$game_system.conf[:mod_level_cap] = 1
$scene = nil
Scene_Base.new.update
check("leaving the options screen hands the DLL the creator's options", asked.call("settings.want").values_at("reason", "pairs").map { |value| value.is_a?(Array) ? value.first : value },
      ["options", ["mod_level_cap", "mod_level_cap=i:1"]])
row.call[:on_change].call(0)
check("turning the row off hands the DLL the switch", asked.call("settings.want").values_at("reason", "on"), ["switch", false])
$told.clear
$settings_steps << [["broadcast", "@shared=o:1;mod_level_cap=i:1", "1a2b"], ["tell", 4, "ff", "1a2b", "@shared=o:1;mod_level_cap=i:1"]]
mods.take(MGQ_Multiplayer::Bridge.call("settings.step"))
check("every player, and a player whose game holds other settings, hears what the DLL says, and the DLL hears who was told",
      [$told, asked.call("settings.told")], [[[-1, { "world_mods" => "1a2b" }, "@shared=o:1;mod_level_cap=i:1"], [4, { "world_mods" => "1a2b" }, "@shared=o:1;mod_level_cap=i:1"]],
                                            { "seat" => 4, "theirs" => "ff", "mine" => "1a2b" }])
Scene_Title.new.start
check("the title screen forgets whose world it was", [row.call, mods.own_world?], [nil, false])

# Mod Config without entries.
contents = NWConst::Config.send(:remove_const, :MOD_CONTENTS)
NWConst::Config.const_set(:MOD_CONTENTS, [])
mods.enter_world(world.call("creator", ""), "me")
check("the row joins a Mod Config without entries too", NWConst::Config::MOD_CONTENTS.map { |entry| entry[:key] }, [row_key])
Scene_Title.new.start
NWConst::Config.send(:remove_const, :MOD_CONTENTS)
NWConst::Config.const_set(:MOD_CONTENTS, contents)

# A world's settings are noted only once its entry goes on.
strict = MGQ_MpWorld::Directory::ListedWorld.new("w2", 4, 0, "creator", 0, "Creator", "Strict", "none", [], false, false, true, false, true, "1:x", "", "", "", "@shared=o:1;mod_level_cap=i:0")
scene = new_scene
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w2", "Strict", strict, nil, false, false))
opening = MGQ_MpWorld.method(:start)
MGQ_MpWorld.define_singleton_method(:start) { |_world, _scene| "It broke." }
scene.start_world(Struct.new(:name, :id).new("Strict", "f2"), false, true, true)
check("a world that fails to open forgets its settings", [mods.instance_variable_get(:@world), row.call], [nil, nil])
MGQ_MpWorld.define_singleton_method(:start) { |_world, _scene| $noted = mods.instance_variable_get(:@world)["id"]; nil }
scene.start_world(Struct.new(:name, :id).new("Strict", "f2"), false, true, true)
check("one that opens has them noted before its save loads", $noted, "w2")
MGQ_MpWorld.define_singleton_method(:start, opening)
Scene_Title.new.start

$world_open = false
$dll["mp_dir_action"] = ""
$dll["mp_dir_list"] = ""

# The Mod Config options an admin's game sends for the catalog mods the DLL names.
$reported_mods = [["levelcap", "Level Cap", "1.4.0"]]
mods.report_options(false)
check("a game that is no admin's sends none", $sent_options, [])
mods.report_options(true)
check("an admin's game sends the options of each mod the DLL names, with the version its copy is, without key bindings, buttons or personal ones", $sent_options,
      [{ "key" => "levelcap", "version" => "1.4.0", "lines" => ["mod_level_cap\tLevel Cap\ti\t1\t1\tOn\t0\tOff", "mod_level_cap_limits\tJob and Race Limits\ti\t1"] }])
$reported_mods = []
check("an option's values come from its :values too, as Mod Config Remake reads them", mods.option_line(NWConst::Config::MOD_CONTENTS.find { |entry| entry[:key] == :mod_party_sheet_size }),
      "mod_party_sheet_size\tSize\ti\t2\t2\t2\t4\t4")

# The world's mods the player's game runs, which the battle server runs too for a battle it hosts.
$served_mods = [["levelcap", "link", "1.4.0", [["Level_Cap.rb", "bb"]]], ["ownmod", "", "", []]]
mods.enter_world(MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, "creator", 0, "Creator", "Modded", "none", [], false, false, true, false, false, "",
                                                         "!Level Cap; Party Sheet; Own Mod", "", "", ""), "me")
check("the battle server gets the world's mods as the DLL lists them", mods.served_mods, $served_mods)
check("and the player's options of them", mods.served_settings.split(";").map { |pair| pair.split("=")[0] }.include?("mod_level_cap"), true)
mods.forget_world
check("outside a world it gets none", [mods.served_mods, mods.served_settings], [[], ""])
check("nothing failed but the broken dumps", ($log || []).grep(/FAILED|failed/).reject { |line| line.include?("broken entry") || line.include?("is not loaded") || line.include?("Too many requests") }, [])

# The Mod Framework's options lock the options a world sets in place of Mod Config Remake.
module Mod_Framework; module Options; class << self; attr_accessor :world_keys; end; end; end
ModConfigRemake.world_keys = nil
mods.lock([:mod_level_cap])
check("the Mod Framework's options lock the options a world sets, Mod Config Remake's then none", [Mod_Framework::Options.world_keys, ModConfigRemake.world_keys], [[:mod_level_cap], nil])
