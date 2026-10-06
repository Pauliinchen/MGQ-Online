#----------------------------------------------------------------
#  world_mods_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-06: Covered a load_game that a translation plugin replaced
#                            - Covered a link to a zip of a release
#                            - Created
#
#----------------------------------------------------------------

# Checks a world's required mods (world_mods.rbx, world_screen.rbx): the relay's mod catalog, a
# game's copies against it and against the creator's hashes, the offer to download and restart,
# entering the world again afterwards, and the creator's mod settings while in the world.

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
class Scene_Title; def start; end; def create_command_window; end; def update; end; def terminate; end; def scene_changing?; false; end; end
class Window_TitleCommand; def make_command_list; end; end
module Sound; %w[cursor ok cancel buzzer].each { |s| define_singleton_method("play_#{s}") { $sounds << s } }; end
module Input; def self.trigger?(button); ($buttons || []).include?(button); end; end
module SceneManager
  def self.call(scene); $called = scene; end
  def self.exit; $exited = true; end
  def self.scene; Object.new.tap { |scene| def scene.prepare(*); end }; end
end
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
    MOD_CONTENTS = [
      { :key => :mod_level_cap, :name => "[Level Cap] Level Cap", :sub => true },
      { :key => :mod_level_cap_limits, :name => "     -> Job and Race Limits", :sub => true },
      { :key => :mod_level_cap_look, :name => "   Window Colour", :sub => true, :personal => true },
      { :key => :mod_party_sheet_hotkey, :name => "[Party Sheet] Hotkey", :sub => true, :keybind => true },
      { :key => :mod_party_sheet_theme, :name => "[Party Sheet] Theme", :sub => true },
      { :key => :mod_party_sheet_write, :name => "     -> Write Party Sheet", :sub => false },
      { :key => :global_thing, :name => "Global Thing", :sub => true },
      { :key => :return, :name => "Return", :sub => false },
    ]
  end
end
module ModConfigRemake
  class << self; attr_accessor :world_keys; end
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
        $calls << [name, signature, args]
        case name
        when "mp_mod_hash"
          hash = $file_hashes[args[0].chomp("\0")]
          return 0 unless hash

          args[1][0, hash.size] = hash
          hash.size
        when "mp_restart_game" then $restart
        else 1
        end
      end
    end
    def self.function(name, signature); Function.new(name, signature); end
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

    # The world screen: the offer.
    $file_hashes = { "Patch/Mods/Level Cap.rb" => "aa" }
    File.write(File.join(folder, "Patch", "Mods", "Level Cap.rb"), "")
    mods.forget_installed
    listed.mods = "!Level Cap"
    scene = new_scene
    scene.instance_variable_set(:@entry, MGQ_MpWorld::Entry.new("w1", "Modded", listed, nil, false, false))
    scene.on_enter
    check("entering with an older version offers to download it, to see the mods, or to go back", [said(scene), scene.instance_variable_get(:@confirm_window).choices.map { |choice| choice[1] }],
          ["Modded uses other versions of these mods: Level Cap. Download them and restart?", [:yes, :show_mods, :cancel]])
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
          ["Modded uses other versions of these mods: Other Mod (get it from its author).", [:show_mods, :cancel], ["buzzer"]])
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

# The creator's settings.
$game_system.conf = { :mod_level_cap => 0, :mod_party_sheet_theme => :dark, :mod_party_sheet_hotkey => 0x51, :global_thing => 5 }
check("the creator's settings are those of the required mods' options, no key bindings, buttons or personal ones", mods.settings_of("!Level_Cap; !Party Sheet; Free"),
      "mod_level_cap=i:0;mod_level_cap_limits=i:1;mod_party_sheet_theme=y:dark")
check("values keep their type, and semicolons and equal signs survive", ["i:-3", "f:1.5", "b:true", "b:false", "y:dark", mods.encode("a;b=c%")].map { |text| mods.decode(text) },
      [[true, -3], [true, 1.5], [true, true], [true, false], [true, :dark], [true, "a;b=c%"]])
check("a large decimal as Ruby writes it survives", mods.decode(mods.encode(1.0e20)), [true, 1.0e20])
check("an unknown type is left out", [mods.decode("x:1"), mods.encode([1])], [[false, nil], nil])

module MGQ_MpWorld; def self.open?; $world_open; end; end
$world_open = true
$game_system.conf = { :mod_level_cap => 1 }
mods.use("mod_level_cap=i:0;broken;mod_party_sheet_theme=y:dark")
DataManager.load_game(1)
check("a save loaded in a world takes the world's settings, and Mod Config Remake shows them as set by the world",
      [$game_system.conf, ModConfigRemake.world_keys], [{ :mod_level_cap => 0, :mod_party_sheet_theme => :dark }, [:mod_level_cap, :mod_party_sheet_theme]])
# The newest translation's plugin 299 replaces load_game after the Patch folder loaded.
module DataManager; def self.load_game(index); load_game_without_rescue(index); end; end
$game_system.conf = { :mod_level_cap => 1 }
DataManager.load_game(1)
check("a load_game a translation plugin replaced still takes the world's settings", $game_system.conf[:mod_level_cap], 0)
$game_system.conf = {}
DataManager.setup_new_game
check("so does a new game in a world", $game_system.conf, { :mod_level_cap => 0, :mod_party_sheet_theme => :dark })
Scene_Title.new.start
check("the title screen lets every option be changed again", ModConfigRemake.world_keys, [])
$world_open = false
$game_system.conf = {}
DataManager.setup_new_game
check("outside a world nothing is set", $game_system.conf, {})
check("nothing failed", ($log || []).grep(/FAILED|failed/), [])
