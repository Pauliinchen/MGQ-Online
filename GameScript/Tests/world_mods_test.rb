#----------------------------------------------------------------
#  world_mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-08: Covered the marker and settings from before it, the row of Shared Mod Settings for the creator and another player, the creator's
#                              options sent only on a change and keeping those their game does not know, turning sharing off and on, live changes and
#                              their notices, values a copy does not offer, and the options dump
#                            - Covered the settings the relay took last over an older list, a seat checked anew after its player left, settings that
#                              cannot be sent or get no answer, notices within three lines, the stay named anew right after a load, the details'
#                              mods, the edit form's texts and an options dump into a folder outside ASCII
#                            - Removed the checks of the creator's button, which is gone
#                            - Covered settings applied only for options a world may set, the restart under Wine, settings someone else set on the relay,
#                              the creator's changes joined to them, the directory's one answer for the world screen and the settings and a refused entry
#                              leaving no settings behind
#                            - Let the DLL's stand-in hold a started action as busy and forget it once cleared
#      Paulinchen  2026-10-07: Covered the options sent from a copy of an older or of no known version while the relay lacks the current version's
#                            - Looked each DLL call's signature up in the export table of Multiplayer.rb
#      Paulinchen  2026-10-06: Expected the summary to name mods that are missing or in another version
#                            - Told whether a small window of the world screen takes input, which an entry after a restart waits for
#                            - Covered the catalog kept while the list loads, links the relay could not read yet, options with :values,
#                              the 2000 characters of the settings, long names among the creator's hashes and options sent once a session
#                            - Refused a DLL call whose arguments differ from its signature
#                            - Covered the Mod Config options an admin's game sends for the catalog
#                            - Covered the creator's button in Mod Config and the creator's unlocked options
#                            - Covered a load_game that a translation plugin replaced
#                            - Covered a link to a zip of a release
#                            - Created
#
#----------------------------------------------------------------

# Checks a world's required mods (world_mods.rbx, world_screen.rbx): the relay's mod catalog, a
# game's copies against it and against the creator's hashes, the offer to download and restart,
# entering the world again afterwards, the mod settings a world shares while in it, and the options
# dump for the World Admin tool.

require "fileutils"
require "tmpdir"

require_relative "support"

# Stand-ins for the game.
class Scene_Base; def return_scene; $returned = true; end; def update; end; end
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
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; def scene_changing?; false; end; end
class Window_TitleCommand; def make_command_list; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
module Input; def self.trigger?(button); ($buttons || []).include?(button); end; end
module SceneManager
  def self.call(scene); $called = scene; end
  def self.exit; $exited = true; end
  def self.scene; $scene || Object.new.tap { |scene| def scene.prepare(*); end }; end
end
class Scene_Config; end
module DataManager
  def self.save_system; end
  def self.load_game(index); load_game_without_rescue(index) rescue false; end
  def self.load_game_without_rescue(_index); $loaded = true; end
  def self.setup_new_game; $new_game = true; end
end
GameSystem = Struct.new(:conf)
$game_system = GameSystem.new({})

# The options mods offer in Mod Config Remake, and its lock.
module NWConst
  module Config
    DEFAULT = { :mod_level_cap => 1, :mod_level_cap_limits => 1 }
    DATA = { :mod_level_cap => [1, 0] }
    DATA_TEXT = { :mod_level_cap => { 1 => { :name => "On" }, 0 => { :name => "Off" } } }
    MOD_CONTENTS = [
      { :key => :mod_level_cap, :name => "[Level Cap] Level Cap", :sub => true },
      { :key => :mod_level_cap_limits, :name => "     -> Job and Race Limits", :sub => true },
      { :key => :mod_level_cap_look, :name => "   Window Colour", :sub => true, :personal => true },
      { :key => :mod_party_sheet_hotkey, :name => "[Party Sheet] Hotkey", :sub => true, :keybind => true },
      { :key => :mod_party_sheet_theme, :name => "[Party Sheet] Theme", :sub => true },
      { :key => :mod_party_sheet_write, :name => "     -> Write Party Sheet", :sub => false },
      { :key => :mod_party_sheet_size, :name => "     -> Size", :sub => true, :values => lambda { [2, 4] } },
      { :key => :tab_opt, :name => "[Tab\tMod] Opt\tion", :sub => true, :values => [1, 2] },
      { :key => :mod_mp_backline, :name => "[Monster Girl Quest! Online] PvP Backline", :sub => true },
      { :key => :global_thing, :name => "Global Thing", :sub => true },
      { :key => :return, :name => "Return", :sub => false },
    ]
  end
end
module ModConfigRemake
  class << self; attr_accessor :world_keys; end
end

# Stand-ins for the world room, which keep what is told and who takes what, and for the
# notification box, which keeps its messages in the order posted.
$told = []
$notices = []
module MGQ_MpOverworldSync
  @routes = {}
  @fields = []
  class << self; attr_reader :routes, :fields, :leave; end
  def self.route(field, &handler); @routes[field] = handler; end
  def self.on_observe(&_block); end
  def self.on_leave(&block); @leave = block; end
  def self.state_fields(&block); @fields << block; end
  def self.tell(seat, fields, body = ""); $told << [seat, fields, body] unless $tell_fails; !$tell_fails; end
  def self.who(peer); peer ? peer.state["name"] : "nobody"; end
  module Peers; Peer = Struct.new(:seat, :state); end
end
module MGQ_MpNotices
  def self.message(key, text, _frames = 180); drop(key); $notices << [key, text]; end
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
$file_hashes = {}
$restart = 1
$ini = {}
module MGQ_Multiplayer
  UPDATE_MESSAGE = "Update."
  def self.available?; true; end
  def self.outdated?; false; end
  def self.clean(text); text; end
  def self.path(name); name; end
  module Log; def self.write(message); ($log ||= []) << message; end; end
  module Player
    def self.share; end
    def self.name; "Me"; end
    def self.setting(key); $ini[key]; end
    def self.store(key, value); $ini[key] = value.to_s; end
  end
  module Ini; def self.read(_path); {}; end; end
  module Link
    Function = Struct.new(:name, :signature) do
      def call(*args)
        check_dll_call(name, args)
        $calls << [name, signature, args]
        case name
        when "mp_mod_hash"
          hash = $file_hashes[args[0].chomp("\0")]
          return 0 unless hash

          args[1][0, hash.size] = hash
          hash.size
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
    def self.function(name); Function.new(name, dll_signature(name)); end
    def self.read(name, _size); $dll[name].to_s; end
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
load_script "world_text"
load_script "world_screen"

# A small window of the world screen: keeps the commands it opened with.
class FakeChoice
  attr_reader :choices
  def start(choices); @choices = choices; end
  def finish; @choices = nil; end
  def activate; end
  def deactivate; end
  def unselect; end
  def active; !@choices.nil?; end
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
# @param lines [Array<String>] The catalog's lines.
def catalog(*lines)
  $dll["mp_mods_list"] = "state=ready\n\n" + lines.map { |line| line + "\n" }.join
  MGQ_MpWorldMods.forget_installed
end

mods = MGQ_MpWorldMods
listed = MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, "creator", 0, "Creator", "Modded", "none", [], false, false, true, false, false, "", "", "", "", "")

# The catalog.
catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "old\tlevelcap\t1.4.0\tLevel_Cap.rb\tbb", "old\tlevelcap\t1.3.5\tLevel_Cap.rb\taa",
        "mod\tpack\tPack\tupload\t2\tPack/a.luka\tp1\tPack/b.luka\tp2")
known = mods.catalog
check("the catalog reads each mod with its files and versions", [known.map(&:key), known[0].files, known[0].versions.map(&:first), known[1].files.keys], [["levelcap", "pack"], { "Level_Cap.rb" => "bb" }, ["1.4.0", "1.3.5"], ["Pack/a.luka", "Pack/b.luka"]])
check("a mod is found by its name as a world writes it", [mods.mod_named("Level_Cap").name, mods.mod_named("level cap").key, mods.mod_named("Other")], ["Level Cap", "levelcap", nil])
$dll["mp_mods_list"] = "state=failed\nerror=down\n\n"
mods.forget_installed
check("a catalog that could not be fetched is unknown", mods.catalog, nil)
catalog("mod\tbroken\tBroken\tlink\t", "old\tbroken\t")
check("a link the relay could not read yet is left out, so a world checks it as a mod outside the catalog", mods.catalog, [])
catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb")
mods.catalog
$dll["mp_mods_list"] = "state=loading\n\nmod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb\n"
mods.forget_installed
check("while the list is fetched again, the catalog the DLL still hands out counts", mods.catalog.map(&:key), ["levelcap"])
$dll["mp_mods_list"] = "state=loading\n\n"
mods.forget_installed
check("and without one, the catalog read before stays", mods.catalog.map(&:key), ["levelcap"])

Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch", "Mods"))
  File.write(File.join(folder, "Patch", "Mods", "Level Cap.rb"), "")
  File.write(File.join(folder, "Patch", "Other_Mod.rb"), "")

  Dir.chdir(folder) do
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "old\tlevelcap\t1.4.0\tLevel_Cap.rb\tbb", "old\tlevelcap\t1.3.5\tLevel_Cap.rb\taa",
            "mod\tpack\tPack\tupload\t2\tPack/a.luka\tp1", "mod\thero\tHero\tzip\t1.1\tHero.rb\th2\tHero/a.luka\th3", "old\thero\t1.0\tHero.rb\th1\tHero/a.luka\th3")

    # Link mods.
    listed.mods = "!Level Cap"
    $file_hashes = { "Patch/Mods/Level Cap.rb" => "bb" }
    check("the world's version of a link mod lets the game in", mods.differing(listed), [])
    $file_hashes = { "Patch/Mods/Level Cap.rb" => "aa" }
    mods.forget_installed
    row = mods.differing(listed).first
    check("an older version is named, and replaced where it is", [row.text, row.downloadable?, row.target], ["Level Cap: yours 1.3.5, the world's 1.4.0", true, "Patch/Mods/Level Cap.rb"])
    $file_hashes = { "Patch/Mods/Level Cap.rb" => "cc" }
    mods.forget_installed
    check("a copy the relay never saw is unknown", mods.differing(listed).first.text, "Level Cap: yours unknown, the world's 1.4.0")
    File.delete(File.join(folder, "Patch", "Mods", "Level Cap.rb"))
    mods.forget_installed
    row = mods.differing(listed).first
    check("a missing link mod goes into Patch under its release's name", [row.text, row.target], ["Level Cap: not installed, the world's 1.4.0", "Patch/Level_Cap.rb"])

    # Uploaded mods.
    listed.mods = "!Pack"
    $file_hashes = { "Patch/Pack/a.luka" => "p1" }
    mods.forget_installed
    check("an uploaded mod whose every file matches lets the game in", mods.differing(listed), [])
    $file_hashes = {}
    mods.forget_installed
    check("one without its files is not installed", mods.differing(listed).first.text, "Pack: not installed, the world's 2")

    # Links to a zip of a release.
    listed.mods = "!Hero"
    $file_hashes = { "Patch/Hero.rb" => "h2", "Patch/Hero/a.luka" => "h3" }
    mods.forget_installed
    check("a zip of a release whose every file matches lets the game in", mods.differing(listed), [])
    $file_hashes = { "Patch/Hero.rb" => "h1", "Patch/Hero/a.luka" => "h3" }
    mods.forget_installed
    row = mods.differing(listed).first
    check("an older zip of a release is named by its version and checked file by file", [row.text, row.downloadable?, row.target], ["Hero: yours 1.0, the world's 1.1", true, nil])

    # Mods outside the catalog.
    listed.mods = "!Other Mod; !Missing Mod"
    listed.mod_hashes = "Other Mod=#{'e' * 64}"
    $file_hashes = { "Patch/Other_Mod.rb" => "e" * 64 }
    mods.forget_installed
    rows = mods.differing(listed)
    check("a mod outside the catalog matches the creator's hash, and a missing one is only named", rows.map(&:text), ["Missing Mod: not installed"])
    $file_hashes = { "Patch/Other_Mod.rb" => "f" * 64 }
    mods.forget_installed
    rows = mods.differing(listed)
    check("another copy than the creator's is named and cannot be downloaded", [rows[0].text, rows[0].downloadable?], ["Other Mod: yours differs from the world creator's copy", false])
    listed.mod_hashes = ""
    mods.forget_installed
    check("without the creator's hash, an installed mod is enough", mods.differing(listed).map(&:name), ["Missing Mod"])

    # The creator's hashes.
    check("the creator's game hashes only required mods outside the catalog that it has", mods.creator_hashes("!Level Cap; !Other Mod; Free Mod; !Missing Mod"), "Other Mod=#{'f' * 64}")
    long = "M" * (MGQ_MpWorldMods::MAX_HASH_NAME_CHARS + 1)
    File.write(File.join(folder, "Patch", "#{long}.rb"), "")
    $file_hashes = { "Patch/Other_Mod.rb" => "f" * 64, "Patch/#{long}.rb" => "f" * 64 }
    mods.forget_installed
    check("a name longer than the relay takes is left out of the creator's hashes", mods.creator_hashes("!Other Mod; !#{long}"), "Other Mod=#{'f' * 64}")
    File.delete(File.join(folder, "Patch", "#{long}.rb"))

    # The world screen: the offer.
    $file_hashes = { "Patch/Mods/Level Cap.rb" => "aa" }
    File.write(File.join(folder, "Patch", "Mods", "Level Cap.rb"), "")
    mods.forget_installed
    listed.mods = "!Level Cap"
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false))
    scene.on_enter
    check("entering with an older version offers to download it, to see the mods, or to go back", [said(scene), scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }],
          ["Modded needs mods that are missing or in another version here: Level Cap. Download them and restart?", [:yes, :show_mods, :cancel]])
    $calls.clear
    scene.on_confirmed
    install = $calls.find { |call| call[0] == "mp_mods_install" }
    check("download hands each mod and where it goes to the DLL", [install && install[2], scene.instance_variable_get(:@busy)], [["levelcap\tPatch/Mods/Level Cap.rb\0"], "mods"])

    $dll["mp_dir_action"] = "state=done\nkind=mods\n\n"
    $exited = false
    scene.follow_action
    check("once installed, the game closes to start again and enter the world", [$ini["rejoin"], $exited], ["w1", true])
    $ini["rejoin"] = ""
    $restart = 0
    $exited = false
    scene.instance_variable_set(:@busy, "mods")
    scene.follow_action
    check("when it cannot start again, it says what to do and stays", [$ini["rejoin"], $exited, said(scene)], ["", false, "The mods were installed. Close the game and start it again to enter Modded."])
    $restart = 1

    $restart = 2
    scene.instance_variable_set(:@busy, "mods")
    scene.follow_action
    check("under Wine or Proton it stays, keeps the world to enter once the player started the game again, and says so", [$ini["rejoin"], $exited, said(scene)],
          ["w1", false, "The mods were installed. Restart the game by hand: it enters Modded once it is back."])
    $ini["rejoin"] = ""
    $restart = 1

    # A mod only its author has.
    listed.mods = "!Other Mod"
    listed.mod_hashes = "Other Mod=#{'e' * 64}"
    $file_hashes = { "Patch/Other_Mod.rb" => "f" * 64 }
    mods.forget_installed
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false))
    $sounds.clear
    scene.on_enter
    check("a mod the relay cannot give is named, with no download", [said(scene), scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }, $sounds],
          ["Modded needs mods that are missing or in another version here: Other Mod (get it from its author).", [:show_mods, :cancel], ["buzzer"]])
    check("the mods box shows the difference", scene.mod_lines(listed.mods, nil, mods.differing(listed)), [[:head, "Mods (1)"], [:item, "Other Mod", :gold, "required, yours differs from the world creator's copy"]])
  end
end

# Entering again after the restart.
$ini["rejoin"] = "w1"
$called = nil
title = Scene_Title.new
mods.on_title_update(title)
check("the title screen opens the world screen once to enter the world again", [$called, mods.rejoining, $ini["rejoin"]], [Scene_MpWorlds, "w1", ""])
scene = new_scene
entered = []
scene.define_singleton_method(:on_enter) { entered << @entry.id }
scene.rejoin([MGQ_MpWorld::Entry.new("w0", "Other", nil, nil, false, false), MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false)], "loading")
check("it waits for the list", [entered, mods.rejoining], [[], "w1"])
scene.rejoin([MGQ_MpWorld::Entry.new("w0", "Other", nil, nil, false, false), MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false)], "ready")
check("then enters the world, once", [entered, mods.rejoining], [["w1"], nil])

# The settings a creator shares.
$game_system.conf = { :mod_level_cap => 0, :mod_party_sheet_theme => :dark, :mod_party_sheet_hotkey => 0x51, :global_thing => 5 }
check("shared settings are the marker, then the creator's options of the named mods, required or listed, no key bindings, buttons or personal ones",
      mods.shared_text("!Level_Cap; Party Sheet; Free", "")[0], "@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1;mod_party_sheet_theme=y:dark")
check("they keep the world's options the creator's game does not know, and drop those it knows of mods the world no longer names",
      mods.shared_text("!Level_Cap", "@shared=o:1;mod_other=i:3;mod_level_cap=i:1;mod_party_sheet_theme=y:light")[0], "@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1;mod_other=i:3")
check("settings join as long as they fit into the relay's 2000 characters", mods.fit_settings([[:a, "a=s:#{'x' * 1990}"], [:b, "b=s:#{'y' * 20}"], [:c, "c=i:1"]]),
      ["a=s:#{'x' * 1990};c=i:1", [:b]])
check("values keep their type, and semicolons and equal signs survive", ["i:-3", "f:1.5", "b:true", "b:false", "y:dark", mods.encode("a;b=c%")].map { |text| mods.decode(text) },
      [[true, -3], [true, 1.5], [true, true], [true, false], [true, :dark], [true, "a;b=c%"]])
check("a large decimal as Ruby writes it survives", mods.decode(mods.encode(1.0e20)), [true, 1.0e20])
check("an unknown type is left out", [mods.decode("x:1"), mods.encode([1])], [[false, nil], nil])
check("the marker is no option", mods.settings_from("@shared=o:1;mod_level_cap=i:0;broken"), { :mod_level_cap => 0 })
check("settings are shared once they hold anything, the marker or options of a world from before it; empty ones leave every player their own",
      ["@shared=o:1", "mod_level_cap=i:0", "", nil].map { |text| mods.shared?(text) }, [true, true, false, false])
check("the edit form shares a world's settings as they are, the marker first", [mods.with_marker(""), mods.with_marker("mod_level_cap=i:0"), mods.with_marker("@shared=o:1;a=i:1")],
      ["@shared=o:1", "@shared=o:1;mod_level_cap=i:0", "@shared=o:1;a=i:1"])

# Another player's game in a world that shares its creator's settings.
module MGQ_MpWorld; def self.open?; $world_open; end; end
row_key = MGQ_MpWorldMods::SHARED_OPTION
row = lambda { NWConst::Config::MOD_CONTENTS.find { |entry| entry[:key] == row_key } }
creator = MGQ_MpOverworldSync::Peers::Peer.new(2, { "id" => "creator", "name" => "Creator" })
stranger = MGQ_MpOverworldSync::Peers::Peer.new(3, { "id" => "p3", "name" => "Stranger" })
live = lambda { |peer, text| MGQ_MpOverworldSync.routes["world_mods"].call(peer, { "world_mods" => mods.crc_of(text), :payload => text }) }
world = lambda { |creator_id, settings| MGQ_MpWorld::Directory::ListedWorld.new("w1", 4, 0, creator_id, 0, "Creator", "Modded", "none", [], false, false, true, false, false, "", "!Level Cap; Party Sheet", "", "", settings) }
check("the details name the mods whose options a world shares as this game knows them, and say when it shares none yet",
      [mods.details_text(world.call("creator", "@shared=o:1;mod_party_sheet_theme=y:dark;mod_missing=i:1"), "me"), mods.details_text(world.call("me", "@shared=o:1"), "me"),
       mods.details_text(world.call("creator", "@shared=o:1;mod_missing=i:1"), "me"), mods.details_text(world.call("creator", ""), "me")],
      ["Mod settings: shared by Creator (Party Sheet)", "Mod settings: shared by you (none set yet)", "Mod settings: shared by Creator (1 option of mods you lack)", "Mod settings: each player's own"])
Scene_Title.new.start
$world_open = true
check("outside a world Mod Config has no row of Shared Mod Settings", row.call, nil)
mods.enter_world(world.call("creator", "@shared=o:1;mod_level_cap=i:0;mod_party_sheet_theme=y:dark;mod_missing=i:7"), "me")
check("entering a world adds the row to Monster Girl Quest! Online's group, personal, with On and Off",
      [row.call[:name], row.call[:sub], row.call[:personal], NWConst::Config::DATA[row_key], NWConst::Config::DATA_TEXT[row_key].map { |value, text| [value, text[:name]] }, NWConst::Config::MOD_CONTENTS.last[:key]],
      ["[Monster Girl Quest! Online] Shared Mod Settings", true, true, [1, 0], [[1, "On"], [0, "Off"]], :return])
check("another player sees it greyed out, chosen by the world's creator", [row.call[:enable].call, row.call[:help].call],
      [false, "Creator created this world and chose this. While On, the world's mod options are set for you here."])
$game_system.conf = { :mod_level_cap => 1 }
$notices.clear
DataManager.load_game(1)
check("a save loaded in the world takes its settings, and Mod Config Remake shows them as set by the world",
      [$game_system.conf.values_at(:mod_level_cap, :mod_party_sheet_theme, row_key), ModConfigRemake.world_keys], [[0, :dark, 1], [:mod_level_cap, :mod_party_sheet_theme]])
check("but none of a mod the player lacks, of the game's own options, of a key binding or of an option marked personal",
      [$game_system.conf.key?(:mod_missing), mods.apply_values(:global_thing => 9, :mod_party_sheet_hotkey => 1, :mod_level_cap_look => 2, :mod_level_cap => 0),
       $game_system.conf.keys & [:global_thing, :mod_party_sheet_hotkey, :mod_level_cap_look]], [false, [:mod_level_cap], []])
check("the player is told whose settings they play with, counting only the options their game has, and that their own saves keep theirs", shown,
      "Creator shares mod settings here: 2 options of Level Cap and Party Sheet are set for you. Your own saves keep yours.")
check("in lines that fit the notification box", fits, [true, true])
$notices.clear
DataManager.load_game(1)
check("once per stay", $notices, [])
$calls.clear
$game_system.conf[row_key] = 0
row.call[:on_change].call(0)
check("the row's change by another player sends nothing and shows the world's choice again", [$calls.map(&:first).grep(/settings/), $game_system.conf[row_key]], [[], 1])
# The newest translation's plugin 299 replaces load_game after the Patch folder loaded.
module DataManager; def self.load_game(index); load_game_without_rescue(index); end; end
$game_system.conf = { :mod_level_cap => 1 }
DataManager.load_game(1)
check("a load_game a translation plugin replaced still takes the world's settings", $game_system.conf[:mod_level_cap], 0)
$game_system.conf = {}
DataManager.setup_new_game
check("so does a new game in a world", [$game_system.conf[:mod_level_cap], $game_system.conf[:mod_party_sheet_theme]], [0, :dark])

# What the creator changes reaches the player at once.
wait_out_notices
$notices.clear
live.call(creator, "@shared=o:1;mod_level_cap=i:1;mod_party_sheet_theme=y:dark;mod_missing=i:7")
check("a change from the creator applies at once, and the player is told what changed", [$game_system.conf[:mod_level_cap], shown],
      [1, "Creator changed the shared mod settings: Level Cap: Off -> On."])
$notices.clear
live.call(creator, "@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:2;mod_party_sheet_theme=y:light;mod_party_sheet_size=i:4;mod_missing=i:8")
check("many changes are named in short and counted", shown, "Creator changed the shared mod settings: Level Cap: On -> Off, Job and Race Limits: 2 and 3 more.")
$game_system.conf[:mod_level_cap] = 1
live.call(stranger, "")
check("settings from a player who did not create the world are ignored", [$game_system.conf[:mod_level_cap], ModConfigRemake.world_keys.include?(:mod_level_cap)], [1, true])
$notices.clear
live.call(creator, "")
check("once the world no longer shares them, the locks are lifted, the values stay and the player is told", [ModConfigRemake.world_keys, $game_system.conf[:mod_party_sheet_theme], $game_system.conf[row_key], shown],
      [[], :light, 0, "Creator stopped sharing mod settings: you can set your own options again. Your save here keeps the values so far."])
$notices.clear
live.call(creator, "@shared=o:1;mod_level_cap=i:5;mod_party_sheet_theme=y:dark")
check("when it shares them again, a value the player's copy does not offer is left out and stays unlocked", [$game_system.conf[:mod_level_cap], ModConfigRemake.world_keys, $log.grep(/do not offer/).size],
      [1, [:mod_party_sheet_theme], 1])
check("and the player is told what is set", shown, "Creator now shares mod settings: 1 option of Party Sheet is set for you. Your own saves keep yours.")
check("the player's state tells which settings their game applies", MGQ_MpOverworldSync.fields.map(&:call), [{ "mod_settings" => mods.crc_of("@shared=o:1;mod_level_cap=i:5;mod_party_sheet_theme=y:dark") }])

# Before a save is loaded, a change waits.
mods.enter_world(world.call("creator", "@shared=o:1;mod_level_cap=i:0"), "me")
$game_system.conf = { :mod_level_cap => 1 }
live.call(creator, "@shared=o:1;mod_level_cap=i:1;mod_party_sheet_theme=y:light")
check("a change before a save is loaded is only noted", [$game_system.conf, ModConfigRemake.world_keys], [{ :mod_level_cap => 1 }, []])
DataManager.load_game(1)
check("and applies with the load", [$game_system.conf[:mod_party_sheet_theme], ModConfigRemake.world_keys], [:light, [:mod_level_cap, :mod_party_sheet_theme]])
$notices.clear
live.call(creator, "@shared=o:1;mod_level_cap=i:0;mod_party_sheet_theme=y:light")
check("settings that arrive right after the load, newer than the player's list, are named anew as what is set, not as a change",
      [$game_system.conf[:mod_level_cap], shown], [0, "Creator shares mod settings here: 2 options of Level Cap and Party Sheet are set for you. Your own saves keep yours."])

# A world that leaves every player their own.
mods.enter_world(world.call("creator", ""), "me")
$game_system.conf = { :mod_level_cap => 1 }
$notices.clear
DataManager.load_game(1)
check("a world that shares no settings sets and locks nothing", [$game_system.conf, ModConfigRemake.world_keys, $notices], [{ :mod_level_cap => 1, row_key => 0 }, [], []])
Scene_Title.new.start
check("the title screen takes the row away and lets every option be changed again", [row.call, ModConfigRemake.world_keys], [nil, []])
$world_open = false
$game_system.conf = {}
DataManager.setup_new_game
check("outside a world nothing is set", $game_system.conf, {})

# The creator's game in their own world.
$world_open = true
$scene = nil
mods.enter_world(world.call("me", "@shared=o:1;mod_other=i:3"), "me")
check("the creator may change the row, whose help says what it does to the others", [row.call[:enable].call, row.call[:help].call],
      [true, "Whether every player in this world plays with your options of its mods. Their own saves keep their own.\r\n←/→ Toggle"])
$game_system.conf = { :mod_level_cap => 0 }
$notices.clear
$calls.clear
DataManager.load_game(1)
sent = lambda { $calls.select { |call| call[0] == "mp_dir_set_settings" }.map { |call| call[2][1].chomp("\0") } }
check("loading in their own world tells the creator whose options they share, naming only mods with options to share", shown, "You share your options of Level Cap with every player here.")
check("and makes their options the world's, keeping in them those their game does not know, unlocked for them",
      [sent.call, $game_system.conf[:mod_other], ModConfigRemake.world_keys], [["@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1;mod_other=i:3"], nil, []])
$dll["mp_dir_action"] = "state=busy\nkind=settings\n\n"
$calls.clear
Scene_Base.new.update
check("while the relay has not answered, nothing is taken", $calls.map(&:first), [])
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
$told.clear
$notices.clear
Scene_Base.new.update
check("its answer is taken in any scene, and every player in the world hears the settings at once",
      [$calls.map(&:first).include?("mp_dir_clear"), $told], [true, [[-1, { "world_mods" => mods.crc_of("@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1;mod_other=i:3") }, "@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1;mod_other=i:3"]]])
check("a load that only took the creator's options tells them nothing more", $notices, [])
$calls.clear
$scene = Scene_Config.new
Scene_Base.new.update
$scene = nil
Scene_Base.new.update
check("leaving the options screen unchanged sends nothing", sent.call, [])
$scene = Scene_Config.new
Scene_Base.new.update
$game_system.conf[:mod_level_cap] = 1
$scene = nil
Scene_Base.new.update
check("leaving it with a changed option sends the creator's options", sent.call, ["@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1;mod_other=i:3"])
$scene = Scene_Config.new
Scene_Base.new.update
$game_system.conf[:mod_level_cap_limits] = 2
$scene = nil
Scene_Base.new.update
check("one request at a time", sent.call.size, 1)
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
$notices.clear
Scene_Base.new.update
check("the creator is told what every player got, and the latest options follow once the first arrived",
      [shown, sent.call], ["Shared with every player: Level Cap: Off -> On.", ["@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1;mod_other=i:3", "@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2;mod_other=i:3"]])
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
Scene_Base.new.update
$told.clear
mods.on_observe(MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "p4", "name" => "Late", "mod_settings" => "abc" }))
mods.on_observe(MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "p4", "name" => "Late", "mod_settings" => "abc" }))
mods.on_observe(MGQ_MpOverworldSync::Peers::Peer.new(5, { "id" => "p5", "name" => "Current", "mod_settings" => mods.crc_of("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2;mod_other=i:3") }))
check("a player whose game holds other settings is told the world's once", $told, [[4, { "world_mods" => mods.crc_of("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2;mod_other=i:3") }, "@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2;mod_other=i:3"]])
late = MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "p4", "name" => "Late", "mod_settings" => "abc" })
MGQ_MpOverworldSync.leave.call(late)
mods.on_observe(late)
check("a player who takes a seat someone left is checked anew, though their game holds the same settings", $told.map(&:first), [4, 4])
dropped = MGQ_MpOverworldSync::Peers::Peer.new(6, { "id" => "p6", "name" => "Dropped", "mod_settings" => "abc" })
$tell_fails = true
mods.on_observe(dropped)
$tell_fails = false
mods.on_observe(dropped)
check("a player whose message did not go out is told as they next tell their state", $told.map(&:first), [4, 4, 6])

# The creator turns sharing off and on in Mod Config.
$calls.clear
$notices.clear
$game_system.conf[row_key] = 0
row.call[:on_change].call(0)
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
Scene_Base.new.update
check("turning it off empties the world's settings, and the creator is told what players get", [sent.call, shown, $told.last[2]],
      [[""], "Shared Mod Settings off: every player here sets their own mod options again.", ""])
$notices.clear
$game_system.conf[:mod_level_cap] = 1
$game_system.conf[:mod_level_cap_limits] = 1
$game_system.conf[row_key] = 1
row.call[:on_change].call(1)
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
Scene_Base.new.update
check("turning it on sends the marker and the creator's options", [sent.call.last, shown, $game_system.conf[row_key]],
      ["@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1", "Shared Mod Settings on: players here get your options of Level Cap.", 1])
$notices.clear
$game_system.conf[:mod_level_cap] = "x" * MGQ_MpWorldMods::MAX_SETTINGS_CHARS
$scene = Scene_Config.new
Scene_Base.new.update
$scene = nil
Scene_Base.new.update
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
Scene_Base.new.update
check("an option past the relay's 2000 characters is left out, and the creator told so first", [sent.call.last, shown, fits],
      ["@shared=o:1;mod_level_cap_limits=i:1", "1 option(s) did not fit and were left out. Shared with every player: Level Cap: On -> no longer shared.", [true, true]])
$game_system.conf[:mod_level_cap] = 1
$notices.clear
$game_system.conf[row_key] = 0
row.call[:on_change].call(0)
$dll["mp_dir_action"] = "state=failed\nkind=settings\nerror=The relay is down.\n\n"
Scene_Base.new.update
check("settings the relay refused are named, and the row shows the world's choice again", [shown, $game_system.conf[row_key]], ["The world's mod settings could not be saved: The relay is down.", 1])
$refused = ["mp_dir_set_settings"]
$notices.clear
$game_system.conf[row_key] = 0
row.call[:on_change].call(0)
told = shown
(MGQ_MpWorldMods::RETRY_FRAMES * 2).times { mods.tick }
check("settings that cannot be sent tell the creator once while they are tried again, and the row shows what is wanted",
      [told, shown, $game_system.conf[row_key]], [MGQ_MpWorldMods::NOT_SENT_TEXT, MGQ_MpWorldMods::NOT_SENT_TEXT, 0])
$refused = []
$notices.clear
(MGQ_MpWorldMods::RETRY_FRAMES + MGQ_MpWorldMods::SEND_FRAMES + 2).times { mods.tick }
check("settings the relay never answers are named, and the row shows the world's choice again", [shown, $game_system.conf[row_key]],
      ["The world's mod settings could not be saved: the relay did not answer.", 1])
Scene_Title.new.start
check("the title screen forgets whose world it was", [row.call, mods.own_world?], [nil, false])

# A list from before the world screen opened.
mods.enter_world(world.call("me", "@shared=o:1;mod_level_cap=i:0"), "me", false)
check("a list from before the world screen opened gives way to the settings the relay took from the creator's game last", mods.latest_text, "@shared=o:1;mod_level_cap_limits=i:1")
mods.enter_world(world.call("me", "@shared=o:1;mod_level_cap=i:0"), "me")
mods.enter_world(world.call("me", "@shared=o:1;mod_level_cap=i:0"), "me", false)
check("a list fetched since counts, an admin's change too, and the settings taken before are forgotten", mods.latest_text, "@shared=o:1;mod_level_cap=i:0")
Scene_Title.new.start

# The creator's edit form.
scene = new_scene
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Modded", world.call("me", ""), nil, false, false))
scene.instance_variable_set(:@busy, "settings")
scene.instance_variable_set(:@shared_settings, "@shared=o:1")
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
scene.follow_action
check("the edit form says its shared settings reach the players once the creator plays in the world", said(scene), "Modded was changed. Its players get your mod options once you play in it.")
scene.instance_variable_set(:@busy, "settings")
scene.instance_variable_set(:@shared_settings, "")
scene.follow_action
check("and that without them, the players set their own from their next visit", said(scene), "Modded was changed. Its players set their own mod options from their next visit.")
scene.instance_variable_set(:@busy, "settings")
$dll["mp_dir_action"] = "state=failed\nkind=settings\nerror=Too many requests.\n\n"
scene.follow_action
check("when only its mod settings fail, it says the other changes were saved", said(scene), "Modded was changed, but its mod settings could not be saved: Too many requests.")
scene.start_action("settings") { false }
check("also when they cannot be sent", said(scene), "Modded was changed, but its mod settings could not be saved: the request could not be started. Try again in a moment.")
$world_open = false
$dll["mp_dir_action"] = ""

# Settings someone else, such as an admin, gave the world on the relay.
$world_open = true
$scene = nil
listing = lambda { |settings| $dll["mp_dir_list"] = "state=ready\n\nworld\tw1\t4\t1\tme\t0\tMe\tModded\tnone\t0\t0\t1\t0\t0\t\t!Level Cap; Party Sheet\t\t\t#{settings}\n" }
let_time_pass = lambda { (MGQ_MpWorldMods::CHECK_FRAMES + 1).times { mods.tick } }
listing.call("@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1")
mods.enter_world(world.call("me", "@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:1"), "me")
$game_system.conf = { :mod_level_cap => 0, :mod_level_cap_limits => 1 }
$calls.clear
DataManager.load_game(1)
check("loading in their own world asks the relay for the world's settings first, and sends nothing while they are as wanted",
      [$calls.map(&:first).include?("mp_dir_refresh"), sent.call], [true, []])
let_time_pass.call
listing.call("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1")
$told.clear
$notices.clear
mods.on_observe(MGQ_MpOverworldSync::Peers::Peer.new(4, { "id" => "p4", "name" => "Late", "mod_settings" => mods.crc_of("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1") }))
check("a player whose game holds other settings has the relay asked first, whose newer settings the creator's game takes, applies and tells every player",
      [mods.latest_text, $game_system.conf[:mod_level_cap], $told, shown],
      ["@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1", 1,
       [[-1, { "world_mods" => mods.crc_of("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1") }, "@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:1"]],
       "The shared mod settings were changed on the relay: Level Cap: Off -> On."])
let_time_pass.call
listing.call("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2")
$scene = Scene_Config.new
Scene_Base.new.update
$game_system.conf[:mod_level_cap] = 0
$scene = nil
Scene_Base.new.update
check("options the creator changes join what changed on the relay meanwhile, which their options then show too",
      [sent.call.last, $game_system.conf[:mod_level_cap_limits]], ["@shared=o:1;mod_level_cap_limits=i:2;mod_level_cap=i:0", 2])
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
Scene_Base.new.update
listing.call("")
let_time_pass.call
$calls.clear
$told.clear
$notices.clear
$scene = Scene_Config.new
Scene_Base.new.update
$game_system.conf[:mod_level_cap] = 1
$scene = nil
Scene_Base.new.update
check("sharing turned off on the relay stays off, whatever options the creator changes", [sent.call, mods.latest_text, $told.map(&:last), shown],
      [[], "", [""], MGQ_MpWorldMods::RELAY_OFF_TEXT])

# One answer of the directory at a time, for the world screen and the world's settings alike.
listing.call("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2")
mods.enter_world(world.call("me", "@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2"), "me")
DataManager.load_game(1)
$scene = Scene_Config.new
Scene_Base.new.update
$game_system.conf[:mod_level_cap] = 0
$scene = nil
$calls.clear
$dll["mp_dir_list"] = "state=loading\n\n"
Scene_Base.new.update
check("while the list is being fetched already, whose answer may be older, the relay is not asked and nothing goes out", $calls.map(&:first) & ["mp_dir_refresh", "mp_dir_set_settings"], [])
listing.call("@shared=o:1;mod_level_cap=i:1;mod_level_cap_limits=i:2")
Scene_Base.new.update
check("once it arrived, the relay is asked and the creator's changed options go out", [$calls.map(&:first).include?("mp_dir_refresh"), sent.call], [true, ["@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:2"]])
MGQ_MpWorld::Directory.claim
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
$calls.clear
Scene_Base.new.update
check("an answer another directory request took the place of is left to that one, and the settings wait to go out again",
      [$calls.map(&:first).include?("mp_dir_clear"), sent.call], [false, []])
$dll["mp_dir_action"] = ""
(MGQ_MpWorldMods::RETRY_FRAMES + 1).times { mods.tick }
check("once it took its answer, the settings go out again", sent.call, ["@shared=o:1;mod_level_cap=i:0;mod_level_cap_limits=i:2"])
Scene_Title.new.start
check("the title screen forgets the settings on their way, though their request still runs", [mods.instance_variable_get(:@sending), MGQ_MpWorld::Directory.free?], [nil, false])
$dll["mp_dir_action"] = "state=done\nkind=settings\n\n"
check("and the next request drops their answer", [MGQ_MpWorld::Directory.free?, $dll["mp_dir_action"]], [true, ""])

# A world's settings are noted only once its entry goes on.
strict = MGQ_MpWorld::Directory::ListedWorld.new("w2", 4, 0, "creator", 0, "Creator", "Strict", "none", [], false, false, true, false, true, "1:x", "", "", "", "@shared=o:1;mod_level_cap=i:0")
differing = MGQ_MpWorld::GameData.method(:differing)
MGQ_MpWorld::GameData.define_singleton_method(:differing) { |_data| ["maps"] }
scene = new_scene
scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w2", "Strict", strict, nil, false, false))
scene.on_enter
check("an entry refused for its game data notes no world and adds no row to Mod Config", [mods.instance_variable_get(:@world), row.call], [nil, nil])
MGQ_MpWorld::GameData.define_singleton_method(:differing, differing)
opening = MGQ_MpWorld.method(:start)
MGQ_MpWorld.define_singleton_method(:start) { |_world, _scene| "It broke." }
scene.instance_variable_set(:@entering, [strict, true])
scene.start_world(Struct.new(:name, :id).new("Strict", "f2"))
check("a world that fails to open forgets its settings", [mods.instance_variable_get(:@world), row.call], [nil, nil])
MGQ_MpWorld.define_singleton_method(:start) { |_world, _scene| $noted = mods.instance_variable_get(:@world)[:id]; nil }
scene.start_world(Struct.new(:name, :id).new("Strict", "f2"))
check("one that opens has them noted before its save loads", $noted, "w2")
MGQ_MpWorld.define_singleton_method(:start, opening)
Scene_Title.new.start

$world_open = false
$dll["mp_dir_action"] = ""
$dll["mp_dir_list"] = ""

# The options dump the World Admin tool reads.
Dir.mktmpdir do |folder|
  target = File.join(folder, "options.txt")
  ENV["MGQMP_OPTIONS_DUMP"] = target
  $ini["rejoin"] = "w9"
  $exited = false
  mods.on_title_update(Scene_Title.new)
  check("a game started for the dump writes every mod's options, without Global ones and Monster Girl Quest! Online's own, ends with end and quits at once",
        [File.open(target, "rb") { |file| file.read }.force_encoding("UTF-8").split("\n"), $exited, $ini["rejoin"], File.exist?("#{target}.tmp")],
        [["mgqmp-options\t1",
          "mod\tlevelcap\tLevel Cap", "opt\tmod_level_cap\tLevel Cap\ti\t1\t1\tOn\t0\tOff", "opt\tmod_level_cap_limits\tJob and Race Limits\ti\t1", "skip\tmod_level_cap_look\tpersonal",
          "mod\tpartysheet\tParty Sheet", "skip\tmod_party_sheet_hotkey\tkeybind", "skip\tmod_party_sheet_theme\ttype", "skip\tmod_party_sheet_write\tbutton", "opt\tmod_party_sheet_size\tSize\ti\t2\t2\t2\t4\t4",
          "mod\ttabmod\tTab Mod", "opt\ttab_opt\tOpt ion\ti\t1\t1\t1\t2\t2",
          "end"], true, "w9", false])
  contents = NWConst::Config.send(:remove_const, :MOD_CONTENTS)
  mods.instance_variable_set(:@dumped, nil)
  $exited = false
  mods.on_title_update(Scene_Title.new)
  NWConst::Config.const_set(:MOD_CONTENTS, contents)
  check("one without Mod Config Remake says so rather than listing no mod", [File.read(target).split("\n"), $exited],
        [["mgqmp-options\t1", "error\tRuntimeError: Mod Config Remake is not loaded", "end"], true])
  mods.instance_variable_set(:@dumped, nil)
  mods.define_singleton_method(:dump_lines) { raise "broken entry" }
  $exited = false
  mods.on_title_update(Scene_Title.new)
  check("one that fails still ends the file and quits", [File.read(target).split("\n"), $exited], [["mgqmp-options\t1", "error\tRuntimeError: broken entry", "end"], true])
  sandbox = File.join(folder, "Sandbox \u00fc")
  FileUtils.mkdir_p(sandbox)
  Dir.chdir(sandbox) do
    ENV["MGQMP_OPTIONS_DUMP"] = File.join(sandbox, "options.txt").tr("/", "\\")
    mods.instance_variable_set(:@dumped, nil)
    $exited = false
    mods.on_title_update(Scene_Title.new)
    check("a dump into the game's folder is written by its file's name alone, which RGSS opens even under a path outside ASCII",
          [mods.dump_path, File.exist?(File.join(sandbox, "options.txt")), $exited], ["options.txt", true, true])
  end
  ENV.delete("MGQMP_OPTIONS_DUMP")
  $ini["rejoin"] = ""
end

# The Mod Config options an admin's game sends for the catalog.
Dir.mktmpdir do |folder|
  FileUtils.mkdir_p(File.join(folder, "Patch"))
  File.write(File.join(folder, "Patch", "Level_Cap.rb"), "")
  File.write(File.join(folder, "Patch", "Party_Sheet.rb"), "")

  Dir.chdir(folder) do
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.0\tLevel_Cap.rb\tbb", "mod\tpartysheet\tParty Sheet\tlink\t1.3.5\tParty_Sheet.rb\tps", "opts\tpartysheet\t1.3.5",
            "mod\tpack\tPack\tupload\t2\tPack/a.luka\tp1")
    $file_hashes = { "Patch/Level_Cap.rb" => "bb", "Patch/Party_Sheet.rb" => "ps" }
    check("the catalog tells which version's options the relay keeps", mods.catalog.map(&:options_version), [nil, "1.3.5", nil])
    $calls.clear
    mods.report_options(false)
    check("a game that is no admin's sends none", $calls.map(&:first).grep(/options/), [])
    mods.report_options(true)
    sent = $calls.select { |call| call[0] == "mp_mods_options" }.map { |call| call[2] }
    check("an admin's game sends the options of each mod it has in the catalog's version that the relay lacks, without key bindings, buttons or personal ones", sent,
          [["levelcap\0", "1.4.0\0", "mod_level_cap\tLevel Cap\ti\t1\t1\tOn\t0\tOff\nmod_level_cap_limits\tJob and Race Limits\ti\t1\0"]])
    $calls.clear
    mods.report_options(true)
    check("once a session", $calls.map(&:first).grep(/options/), [])
    mods.forget_installed
    mods.report_options(true)
    check("also when the world screen opens again", $calls.map(&:first).grep(/options/), [])
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.1\tLevel_Cap.rb\tcc", "old\tlevelcap\t1.4.0\tLevel_Cap.rb\tbb", "opts\tlevelcap\t1.4.1",
            "mod\tpartysheet\tParty Sheet\tlink\t1.3.6\tParty_Sheet.rb\tqq", "old\tpartysheet\t1.3.5\tParty_Sheet.rb\tps", "opts\tpartysheet\t1.3.5")
    mods.report_options(true)
    check("a copy of an older version sends nothing while the relay has the current version's options or that older version's", $calls.map(&:first).grep(/options/), [])
    catalog("mod\tlevelcap\tLevel Cap\tlink\t1.4.1\tLevel_Cap.rb\tcc", "old\tlevelcap\t1.4.0\tLevel_Cap.rb\tbb",
            "mod\tpartysheet\tParty Sheet\tlink\t1.3.6\tParty_Sheet.rb\tqq", "opts\tpartysheet\t1.3.5", "mod\tpack\tPack\tupload\t2\tPack/a.luka\tp1")
    $file_hashes["Patch/Party_Sheet.rb"] = "zz"
    mods.forget_installed
    mods.report_options(true)
    sent = $calls.select { |call| call[0] == "mp_mods_options" }.map { |call| call[2][0, 2] }
    check("while the relay lacks the current version's options, a copy of an older version sends them with its version, one of no known version with none, and a mod not installed sends nothing",
          sent, [["levelcap\0", "1.4.0\0"], ["partysheet\0", "\0"]])
    $calls.clear
    check("an option's values come from its :values too, as Mod Config Remake reads them", mods.option_line(NWConst::Config::MOD_CONTENTS.find { |entry| entry[:key] == :mod_party_sheet_size }),
          "mod_party_sheet_size\tSize\ti\t2\t2\t2\t4\t4")
  end
end
check("nothing failed but the broken dumps", ($log || []).grep(/FAILED|failed/).reject { |line| line.include?("broken entry") || line.include?("is not loaded") || line.include?("Too many requests") }, [])
