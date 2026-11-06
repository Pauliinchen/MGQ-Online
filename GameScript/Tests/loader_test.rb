#----------------------------------------------------------------
#  loader_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Stood in for stay_off, which the stages test covers
#      Paulinchen  2026-11-05: Dropped the raid pools' beaten markers from the formats kept, which the DLL reads now
#                            - Checked that no script builds or reads a format of C#, the network or a store C# reads, naming what stays with why
#                            - Checked that only the bridge loads exports of the DLL and that no script calls an old export or writes or reads a message's key=value lines
#      Paulinchen  2026-11-01: Checked that no script or test names the old interface the screens reached the Mod Framework by
#                            - Checked that none of the HUD's pictures the Mod Framework's components replaced comes back
#                            - Checked that no script or test names the World overview's own drawing
#                            - Checked that no script hooks the game's command windows or puts rows into the options itself
#                            - Checked that no script or test names the old notification box
#                            - Checked that the trade screen is built of framework components
#                            - Checked that no script or test names the old wheel sprites, the action wheel's module or its covering screens
#                            - Checked that the old screens of the story's choices and the replay's question and the parking lists are gone
#                            - Checked that no script or test names the old list, message and info boxes
#                            - Checked that no script or test names the world screen's old windows or its text screen
#                            - Checked that no script or test names the chat's old log and bubble sprites
#      Paulinchen  2026-10-31: Checked that the mod names the lowest Mod Framework before any script loads, that it stays off, logged, with an older one
#                              or one without its DLL, that no script or test names what moved into the framework, that the input's exports are gone and that the served scripts' fingerprint names no framework script
#                            - Dropped the checks of the keys, the mouse, the capture and the guard of Input, which the Mod Framework's tests cover
#                            - Checked that a script calls every export of the table
#      Paulinchen  2026-10-30: Checked the scripts of the first two stages and that a script loads once
#                            - Checked that Multiplayer.rb holds ASCII only and logs and shows the errors of its own load
#      Paulinchen  2026-10-28: Checked the freeze's load order without its deleted data script
#                            - Gave the closing its world room drain topic
#                            - Checked that the scenes ending on a quit or the window closing write the closing line, and the end once
#                            - Checked that no script names an Encoding constant
#      Paulinchen  2026-10-23: Checked that the log's lines wait for the bridge, cross it with the frame and go into the day's file while the mod stays off
#                            - Checked that an error the error box shows is written once
#                            - Checked that a text from the DLL reads as text
#                            - Dropped the checks of the day's file, the repeats, the cut and the old logs, which the DLL's tests cover
#                            - Dropped the checks of the chosen name, which the DLL keeps now
#                            - Dropped the check of the log rules of the deleted options dump
#      Paulinchen  2026-10-17: Checked the load order of the raid boss freeze scripts
#      Paulinchen  2026-10-15: Checked that every export takes at most 16 arguments
#                            - Checked the log of each day and that starting a game deletes those of earlier days
#      Paulinchen  2026-10-13: Checked that ui_single_player.rbx loads after the scripts whose rows it adds
#                            - Checked that battles_raid_tiers.rbx loads after the scripts it builds on and before ui_raid_bar.rbx
#      Paulinchen  2026-10-12: Stood in for Ini.load
#                            - Checked the mouse wheel's notches, read once a frame
#      Paulinchen  2026-10-11: Checked that a log past MAX_BYTES keeps its newest lines
#      Paulinchen  2026-10-10: Checked that a text that grew while read from the DLL is asked for again
#      Paulinchen  2026-10-09: Checked that story_state.rbx loads before the story scripts that build on it
#      Paulinchen  2026-10-08: Checked that a watched key goes down once per frame
#                            - Checked that a held key reads as one press per frame
#                            - Checked how the sessions kept are counted and which logs are deleted
#      Paulinchen  2026-10-07: Checked that a session start deletes all but the last five sessions' logs
#                            - Checked how the log's last line tells the game closing
#                            - Checked that the press closing the last screen reaches the game from the next frame only
#                            - Checked the DLL's export table against the scripts and the DLL
#                            - Checked the in-game log's file per session and its count of scripts loaded
#                            - Checked that clearing the chosen name brings the name on Discord back
#      Paulinchen  2026-10-06: Checked the buttons a closing screen leaves and the guard of Input
#                            - Checked the in-game log's repeated lines and a log grown too large
#                            - Checked that ui_wheel.rbx loads before both wheels
#      Paulinchen  2026-10-04: Checked that coop_gather.rbx loads after coop_events.rbx and coop_castle.rbx after coop_story.rbx
#                            - Followed the scripts to their new names, without mp_
#      Paulinchen  2026-10-03: Checked that a family's base script loads before its other scripts
#                            - Checked that core_log.rbx loads first
#      Paulinchen  2026-10-02: Checked that core_hooks.rbx loads first
#                            - Checked that the scripts whose constants the World overview shares load before it
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# Covers how Multiplayer.rb loads the other scripts: SCRIPTS names exactly the files in
# GameScript/Multiplayer/Scripts, and load_scripts runs them at the top level, in order, logging one
# that fails or is missing while the others still load.

require_relative "bridge_support"
require "tmpdir"

source = File.read(File.expand_path("../Multiplayer.rb", __dir__), encoding: "UTF-8")
scripts = source[/SCRIPTS = %w\[(.*?)\]/m, 1].split
files = Dir[File.join(SCRIPTS_DIR, "*.rbx")].map { |file| File.basename(file, ".rbx") }

check("every script in SCRIPTS is a file", scripts - files, [])
check("every file is in SCRIPTS", files - scripts, [])
check("no script is in SCRIPTS twice", scripts.select { |name| scripts.count(name) > 1 }.uniq, [])
naming = (Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.join(SCRIPTS_DIR, "..", "..", "Multiplayer.rb")]).select { |file| File.read(file, :encoding => "BOM|UTF-8") =~ /Encoding::[A-Z]/ }
check("no script names an Encoding constant, which the game's Ruby lacks", naming.map { |file| File.basename(file) }, [])
check("core_log and core_hooks load first, since every script logs and registers its hooks with them", scripts.first(2), %w[core_log core_hooks])
check("core_actors loads before the scripts whose classes build on Game_MpActor",
      %w[battles_coop battles_pvp].all? { |name| scripts.index("core_actors") < scripts.index(name) }, true)
check("the registries load before the scripts that join them",
      [scripts.index("overworld_sync") < scripts.index("ui_actions"), scripts.index("coop") < scripts.index("coop_events")], [true, true])
check("the scripts whose constants the World overview shares load before it",
      %w[ui_actions overworld battles_pvp].all? { |name| scripts.index(name) < scripts.index("world_overview") }, true)
check("a family's base script loads before its other scripts",
      %w[world battles battles_sync battles_pvp coop].all? { |base| scripts.select { |name| name.start_with?("#{base}_") }.all? { |name| scripts.index(base) < scripts.index(name) } }, true)
check("the party's gathering loads after the events that hand it its messages, the castle after the story it reads",
      [scripts.index("coop_events") < scripts.index("coop_gather"), scripts.index("coop_story") < scripts.index("coop_castle")], [true, true])
check("the story's state model loads before the story scripts that build on it",
      %w[coop_story coop_castle world_story world_catchup coop_choices].all? { |name| scripts.index("story_state") < scripts.index(name) }, true)
check("the battle scripts keep the order their late hooks rely on",
      %w[battles battles_coop battles_sync].map { |name| scripts.index(name) }.each_cons(2).all? { |a, b| a < b }, true)
check("the raid tiers load after the Mod Config rows, the push routes, the boss table and the pools whose rules they share, and before the bars that draw them",
      [%w[ui_online overworld_sync battles_raid_bosses battles_raid_pool].all? { |name| scripts.index(name) < scripts.index("battles_raid_tiers") }, scripts.index("battles_raid_tiers") < scripts.index("ui_raid_bar")],
      [true, true])
check("the single player rows load after the Mod Config rows, the world's sync and the scripts whose settings they show",
      %w[ui_online overworld_sync battles_raid_tiers ui_raid_bar ui_leader_hud].all? { |name| scripts.index(name) < scripts.index("ui_single_player") }, true)
boot = source[/BOOT_SCRIPTS = %w\[(.*?)\]/m, 1].split
world = source[/WORLD_SCRIPTS = %w\[(.*?)\]/m, 1].split
title = boot + world
check("the first stage starts as SCRIPTS does, with the log, the hooks, the hotkeys and the boxes", boot, scripts.first(boot.size))
check("the world screens name scripts of SCRIPTS, in their order, past the first stage", world, scripts.select { |name| world.include?(name) && !boot.include?(name) })
run_hooked = title.select { |name| File.read(File.join(SCRIPTS_DIR, "#{name}.rbx"), :encoding => "BOM|UTF-8").include?("SceneManager.singleton_class, :run") }
check("no script of the title part follows SceneManager.run, which only the Mod Framework's entering lets set up", run_hooked, [])
check("the raid boss freeze loads its engine before the world's list, both after the pools",
      %w[battles_raid_pool battles_raid_freeze world_freeze].map { |name| scripts.index(name) }.each_cons(2).all? { |a, b| a < b }, true)
check("the frozen fights' stand-ins load after the bars that draw over them and the join hotkey that resumes them",
      %w[battles_coop_join battles_raid_freeze world_freeze ui_raid_bar].all? { |name| scripts.index(name) < scripts.index("ui_raid_freeze") }, true)

# The Mod Framework: the lowest version the mod runs with is named before any script loads, and
# nothing the framework took over, nor the old interface the screens reached it by, is named by a
# script or a test any more.
required_at = source.index("MOD_FRAMEWORK_REQUIRED = ")
check("the lowest Mod Framework is named before the scripts and before the mod loads them",
      [source[/MOD_FRAMEWORK_REQUIRED = "([\d.]+)"/, 1], required_at < source.index("SCRIPTS = %w["), required_at < source.index("MGQ_Multiplayer::Stages.boot")],
      ["0.1.0", true, true])
moved = ["MGQ_Multiplayer::Key", "MGQ_Multiplayer::Capture", "MGQ_Multiplayer::Mouse", "MGQ_Multiplayer::Windows", "MGQ_Multiplayer::Background",
         "Link.typing", "mp_typing", "mp_mouse_wheel", "mp_keep_running", "MGQ_MpWheel", "Sprite_MpConfirmBox", "Confirm.tick", "Theme::Skinned",
         "numpad_cancel?", "NUMPAD_CANCEL_KEYS", "CLOSE_KEYS", "Style.close_hint", "MGQ_MpUi", "MGQ_MpScrollingWindow", ":mp_ui_positions",
         ":mp_ui_preset", ":mp_ui_game_windows", "MGQ_MpHotkeys::BINDINGS", ":mp_key_", "Sprite_MpNoticeBox", "Sprite_MpActionWheel", "Sprite_MpEmoteWheel",
         "MGQ_MpActions.cover", "MGQ_MpActions::Wheel", "Sprite_MpListBox", "Sprite_MpMessageBox", "Window_MpInfo", "Window_MpSaveExportNotice", "ui_boxes",
         "Sprite_MpChatLog", "Sprite_MpChatBubble", "Sprite_MpWorldOverview"]
# The hints name the cancel key as the player bound it, never Escape or the numpad's 0 alone.
hinted = ["Esc or Numpad 0", "\"Numpad 0"]
mod_files = Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.expand_path("../Multiplayer.rb", __dir__)]
swept = mod_files + Dir[File.join(__dir__, "*.rb")] - [File.expand_path(__FILE__)]
named = swept.flat_map do |file|
  code = File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#") }.join
  (moved + (mod_files.include?(file) ? hinted : [])).select { |name| code.include?(name) }.map { |name| "#{File.basename(file)}: #{name}" }
end
check("no script or test names what moved into the Mod Framework", named, [])
# The title's and the menu's commands and the options rows go through the Mod Framework.
own_ways = [/MGQ_MpHooks\.\w+\(\s*:*Window_(Title|Menu)Command\b/, /add_original_commands/, /MOD_CONTENTS\.insert/, /register_option/, /\badd_option\b/]
own_commands = mod_files.flat_map do |file|
  code = File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#") }.join
  own_ways.select { |way| code =~ way }.map { |way| "#{File.basename(file)}: #{way.source}" }
end
check("no script hooks the title's or the menu's commands or puts options rows in itself", own_commands, [])
trade_screen = File.read(File.join(SCRIPTS_DIR, "ui_trade.rbx"), :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#") }.join
check("the trade screen is built of framework components, none of the game's windows",
      ["Window_MpTrade", "VisibleRows", "Theme::Skinned", "ScrollingWindow", "< Window_"].select { |name| trade_screen.include?(name) }, [])
# The world screen is built on the framework's components: its old windows and its text screen are
# gone.
gone = %w[Scene_MpText Window_MpTextEdit Window_MpTextInput Window_MpWorldList Window_MpWorldCommands Window_MpWorldDetail Window_MpChoice MpWorldListPane
          MGQ_MpBoxCursor text_result]
left = swept.flat_map do |file|
  code = File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#") }.join
  gone.select { |name| code =~ /\b#{name}\b/ }.map { |name| "#{File.basename(file)}: #{name}" }
end
check("no script or test names the world screen's old windows or its text screen", left, [])
# The HUD lies on the Mod Framework's components: none of the pictures they replaced comes back.
replaced = %w[Sprite_MpLeaderHud Sprite_MpPartyBox Sprite_MpRaidBar Sprite_MpWorldStatus Window_MpWaiting Sprite_MpJoinPrompt Sprite_MpEdgeArrow
              Sprite_MpGhostLabel Sprite_MpOwnPing Sprite_MpOwnLine MGQ_MpHud MGQ_MpLeaderHud.room hud.arrow_picture]
redrawn = swept.flat_map do |file|
  code = File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#") }.join
  replaced.select { |name| code =~ /#{Regexp.escape(name)}/ }.map { |name| "#{File.basename(file)}: #{name}" }
end
check("no script or test names the HUD's pictures the Mod Framework's components replaced", redrawn, [])
csharp = Dir[File.expand_path("../../{MGQOnline.Game,MGQParadox.Multiplayer,MGQOnline.Game.Tests,MGQParadox.Multiplayer.Tests}/**/*.cs", __dir__)].reject { |file| file =~ %r{/(bin|obj)/} }
in_csharp = csharp.flat_map do |file|
  code = File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("//") }.join
  names = %w[UiTopics GameWindow Keyboard MouseWheel AltMenuGuard].select { |name| code =~ /\b#{name}\b/ }
  names << "MGQOnline.Game.Ui" if code.include?("MGQOnline.Game.Ui") && !File.basename(file).start_with?("ScreenshotWalk") && !code.include?("ScreenshotWalk")
  names.map { |name| "#{File.basename(file)}: #{name}" }
end
check("no C# file names the interface's models, the window hook or the keyboard the Mod Framework holds", in_csharp, [])
# The story's choices and the replay's question are the framework's windows: their old screens,
# the mods parking lists and the question's steps are gone. The bug report's C# cases keep the old
# scene's name, the recorded fixture's.
gone = %w[Scene_MpStoryChoices Window_MpStoryChoices Scene_MpStoryQuestion Window_MpStoryQuestion MGQ_MpModParking world_mods_parking
          ParkingRules ParkingTexts choices.input_step]
left = (swept + csharp).flat_map do |file|
  code = File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#", "//") }.join
  names = csharp.include?(file) ? gone - %w[Scene_MpStoryChoices] : gone
  names.select { |name| code.include?(name) }.map { |name| "#{File.basename(file)}: #{name}" }
end
check("no script, test or C# file names the old dialogs' screens, the parking lists or the question's steps", left, [])

# One bridge channel: no script reaches the DLL but through the bridge's four exports, and none
# writes or reads the key=value lines of a message, which C# writes and reads.
mod_code = (Dir[File.join(SCRIPTS_DIR, "*.rbx")] + [File.expand_path("../Multiplayer.rb", __dir__)]).map do |file|
  [File.basename(file), File.read(file, :encoding => "BOM|UTF-8").lines.reject { |line| line.strip.start_with?("#") }.join]
end
check("only the bridge loads exports of the DLL, the four it names",
      [mod_code.select { |_, code| code.include?("Win32API.new") }.map(&:first), source[/      SIGNATURES = \{.*?\n      \}/m].scan(/'(mp_[a-z_]+)'/).flatten],
      [["Multiplayer.rb"], %w[mp_bridge_open mp_call mp_reply mp_drain]])
check("no script calls an old export of the DLL",
      mod_code.select { |_, code| code =~ /\bLink\.(function|read|parse|player_id)\b|MGQ_Multiplayer::Link\b|^\s*module Link\b/ }.map(&:first), [])
check("no script writes or reads the empty line that ends a message's key=value lines", mod_code.select { |_, code| code.include?('\n\n') }.map(&:first), [])

# C# writes and reads every format of the bridge, the network and the stores it reads: no script
# splits a text, dumps or loads a Marshal, compares a flag as "1" or "0" or escapes a text as %XX
# for them. What is kept stays inside the game, each named with why.
format_ways = [/\.split\b/, /\bMarshal\.(dump|load)\b/, /[=!]= "[01]"/, /%3[BD]|%25/, /\.(un)?pack\(/]
kept_formats = [
  ["Multiplayer.rb", "Marshal.", "the bridge itself, which hands its plain values across as Marshal"],
  ["battles_pvp.rbx", "Marshal.", "a snapshot of the game's own objects before a PvP battle, put back after it"],
  ["battles_raid_freeze.rbx", "Marshal.", "the party and the screen at a frozen fight, game objects the save field keeps for this script alone"],
  ["battles_sync.rbx", "class.name.split('::')", "the name of a Ruby class, for the log"],
  ["battles_sync_playback.rbx", "kind.split(\".\", 2)", "a recorded call's name, the game's object and method, which no C# reads"],
  ["coop_scene.rbx", "call.split(\"_\")", "an Audio call's name, the game's method, which no C# reads"],
  ["coop_scene.rbx", "kind.split(\".\", 2)", "a screen call's name, the game's object and method, which no C# reads"],
  ["coop_story.rbx", "Marshal.load(Marshal.dump(party))", "a copy of the game's party"],
  ["story_replay.rbx", "Marshal.", "copies of the game's switches, variables and self switches for the replay's view"],
  ["story_replay.rbx", "path.split(\"::\")", "the name of a Ruby class"],
  ["story_state.rbx", "Marshal.load(Marshal.dump(story))", "a copy of a story's values"],
  ["world_overview_pages.rbx", "match[2].split(\",\")", "the arguments of a check in the game's own event script"],
  ["world_save_distribution.rbx", "Marshal.load(file)", "the game's own save files"],
  ["world_save_distribution.rbx", "name.split(\"::\")", "the name of a Ruby class"],
]
format_uses = mod_code.flat_map do |name, code|
  code.lines.select { |line| format_ways.any? { |way| line =~ way } }.map { |line| [name, line.strip] }
end
check("no script builds or reads a format of C#, the network or a store C# reads; what stays is the game's own",
      format_uses.reject { |name, line| kept_formats.any? { |file, part, _| file == name && line.include?(part) } }.map { |name, line| "#{name}: #{line}" }, [])
check("every format kept is still used, so the list names nothing gone",
      kept_formats.reject { |file, part, _| format_uses.any? { |name, line| name == file && line.include?(part) } }.map { |file, part, _| "#{file}: #{part}" }, [])

# The parts of Multiplayer.rb that load, taken out of it, so they run without the game.
harness = Module.new
%w[MOD_DIR SCRIPTS_DIR SCRIPT_EXTENSION].each do |name|
  harness.const_set(name, eval(source[/#{name} = (".*?")/, 1]))
end
harness.const_set(:SCRIPTS, %w[good broken missing after])
log = []
harness.const_set(:Log, Module.new.tap { |mod| mod.define_singleton_method(:write) { |line| log << line } })
harness.module_eval(source[/  def self\.path\(name\)\n.*?\n  end\n/m])
harness.module_eval(source[/  def self\.load_scripts\(names = SCRIPTS, part = false\)\n.*?\n  end\n/m])
harness.module_eval(source[/  def self\.load_script\(name, part\)\n.*?\n  end\n/m])
harness.define_singleton_method(:stay_off) { nil }

Dir.mktmpdir do |game|
  Dir.chdir(game) do
    folder = File.join("Patch", "Multiplayer", "Scripts")
    Dir.mkdir("Patch")
    Dir.mkdir(File.join("Patch", "Multiplayer"))
    Dir.mkdir(folder)
    File.write(File.join(folder, "good.rbx"), "\xEF\xBB\xBFmodule LoaderTestGood; VALUE = 1; end\nclass Array; def loader_test_good?; true; end; end\n")
    File.write(File.join(folder, "broken.rbx"), "module LoaderTestBroken\n  def self.x(\nend\n")
    File.write(File.join(folder, "after.rbx"), "module LoaderTestAfter; end\n")
    harness.load_scripts
    harness.load_scripts(%w[good after])
  end
end

# The Russian translation's own loader reads Multiplayer.rb as it is, without dropping a byte
# order mark.
first_wide = File.binread(File.expand_path("../Multiplayer.rb", __dir__)).bytes.index { |byte| byte > 0x7f }
check("Multiplayer.rb holds ASCII only, so no byte order mark", first_wide, nil)

check("a script loads at the top level, past a byte order mark",
      [defined?(LoaderTestGood::VALUE) ? LoaderTestGood::VALUE : nil, [].respond_to?(:loader_test_good?)], [1, true])
check("the scripts after one that fails or is missing still load", defined?(LoaderTestAfter) ? true : false, true)
check("a script that does not parse is logged by name", log.any? { |line| line.start_with?("broken.rbx did not load: SyntaxError") }, true)
check("a missing script is logged by name", log.any? { |line| line.start_with?("missing.rbx did not load: Errno::ENOENT") }, true)
check("the log counts the scripts loaded and names those that did not", log[-2], "loaded 2 of 4 scripts, not broken, missing")
check("a script loads once per game session", log.last, "loaded 0 of 0 scripts")

# The log: lines wait for the bridge, then cross it with the frame's batch, each with its time of
# day; while the mod stays off, the scripts write them into the day's file themselves.
MGQ_Multiplayer.const_set(:LOG_DIR, "Logs")
MGQ_Multiplayer.module_eval(source[/  def self\.log_path\(name\)\n.*?\n  end\n/m])
MGQ_Multiplayer.module_eval(source[/  module Log\n.*?\n  end\n/m])
load_bridge
log = MGQ_Multiplayer::Log
crossed = []
flushes = [0]
fake = FakeBridge.new
fake.answer("log.write") { |line| crossed << line; nil }
fake.answer("log.flush") { |_request| flushes[0] += 1; nil }
log.write("starting")
MGQ_Multiplayer::Bridge.open(fake)
log.write("Lukaルカ")
log.write("bytes \xFF".dup.force_encoding("UTF-8"))
MGQ_Multiplayer::Bridge.frame
check("the lines wait while the start has not decided", crossed, [])
log.settle(true)
MGQ_Multiplayer::Bridge.frame
check("then cross in order with the next frame, the bridge's opening among them",
      crossed.map { |_time, line| line.sub(/ with the DLL .*/, "") }, ["starting", "bridge: opened context 1", "Lukaルカ", "bytes \xFF".b])
check("each with the time of day it was written at, a line that is no valid text as its bytes",
      [crossed.all? { |time, _line| time =~ /\A\d\d:\d\d:\d\d\z/ }, crossed.last.last.encoding], [true, Encoding::ASCII_8BIT])
crossed.clear
log.write("the game closes")
log.flush
check("a flush hands a line over at once and has the DLL write every line", [crossed.map(&:last), flushes[0]], [["the game closes"], 1])
MGQ_Multiplayer::Bridge.close

Dir.mktmpdir do |game|
  Dir.chdir(game) do
    log.instance_variable_set(:@early, [])
    log.write("starting")
    log.write("not started: the mod is turned off")
    log.settle(false)
    log.settle(true)
    log.write("loaded 70 of 70 scripts")
    log.flush
    file = File.join("Logs", "Multiplayer #{Time.now.strftime('%Y-%m-%d')}.log")
    lines = File.binread(file).split("\r\n").map { |line| line.split("  ", 2)[1] }
    check("while the mod stays off, the lines and the reason go into the day's file directly, marked as the scripts'",
          [lines, flushes[0]], [["[script] starting", "[script] not started: the mod is turned off", "[script] loaded 70 of 70 scripts"], 1])
  end
end

# The Russian translation's own loader catches no error the file raises, so the file catches the
# errors of its own load, here one the start raises before it settled the log, which leaves the
# hooks that write the log missing too.
module LoaderTestFailing
  BOXES = []
  Log = MGQ_Multiplayer::Log
  module Stages; def self.boot; raise LoadError, "no fiddle"; end; end
  def self.msgbox(text); BOXES << text; end
end
LoaderTestFailing.module_eval(source[/  MOD_FRAMEWORK_REQUIRED = .*\n/])
LoaderTestFailing.module_eval(source[/  def self\.available\?\n.*?\n  end\n/m])
LoaderTestFailing.module_eval(source[/  def self\.framework_ready\?\n.*?\n  end\n/m])
LoaderTestFailing.module_eval(source[/  def self\.load_failed\(stage, error\)\n.*?\n  end\n/m])
Dir.mktmpdir do |game|
  Dir.chdir(game) do
    log.instance_variable_set(:@early, [])
    log.instance_variable_set(:@own_file, nil)
    log.write("starting")
    raised = begin
      eval(source[/^begin\n  MGQ_Multiplayer::Stages\.boot\n.*?^end\n/m].gsub("MGQ_Multiplayer", "LoaderTestFailing"), TOPLEVEL_BINDING)
      nil
    rescue Exception => e
      e
    end
    file = File.join("Logs", "Multiplayer #{Time.now.strftime('%Y-%m-%d')}.log")
    lines = File.exist?(file) ? File.binread(file).split("\r\n").map { |line| line.split("  ", 2)[1][/\A[^:]*(: [^:]*)?/] } : []
    check("an error as Multiplayer.rb loads is never raised, but written into the day's file at once",
          [raised, lines], [nil, ["[script] starting", "[script] loading FAILED: LoadError"]])
    check("and told in the game's message box once, without the error", LoaderTestFailing::BOXES, ["Monster Girl Quest! Online failed to load."])
  end
end

# The gate: a booted Mod Framework that is older than the mod needs, or whose DLL does not run,
# keeps the mod off, and the log says why in one line.
module LoaderTestGate
  LINES = []
  module Log; def self.write(line); LINES << line; end; end
end
LoaderTestGate.module_eval(source[/  MOD_FRAMEWORK_REQUIRED = .*\n/])
%w[available? half_loaded? framework_ready? framework_gap log_framework_gap].each do |name|
  LoaderTestGate.module_eval(source[/  def self\.#{Regexp.escape(name)}\n.*?\n  end\n/m])
end

# Runs the gate as the title stage does once the mod's DLL started, with the framework's DLL on or
# off and the framework at a version.
#
# @param version [String] The booted framework's version.
# @param dll [Boolean] Whether the framework's DLL runs.
# @return [Array] Whether the mod is available and the lines the gate wrote.
def gate_with(version, dll)
  framework_dll = Mod_Framework.instance_variable_get(:@available)
  framework_version = Mod_Framework::VERSION
  Mod_Framework.send(:remove_const, :VERSION)
  Mod_Framework.const_set(:VERSION, version)
  Mod_Framework.available = dll
  LoaderTestGate::LINES.clear
  LoaderTestGate.instance_variable_set(:@available, true)
  LoaderTestGate.log_framework_gap
  [LoaderTestGate.available?, LoaderTestGate::LINES.dup]
ensure
  Mod_Framework.send(:remove_const, :VERSION)
  Mod_Framework.const_set(:VERSION, framework_version)
  Mod_Framework.available = framework_dll
end

check("a booted framework older than the mod needs keeps the mod off, logged once",
      gate_with("0.0.9", true), [false, ["Monster Girl Quest! Online is off: it needs the Mod Framework 0.1.0 or newer, and the one installed is 0.0.9"]])
check("one whose DLL does not run keeps the mod off, logged once",
      gate_with("0.1.0", false), [false, ["Monster Girl Quest! Online is off: the Mod Framework 0.1.0 runs without its DLL"]])
check("one new enough with its DLL lets the mod run and writes nothing", gate_with("0.1.0", true), [true, []])

# The rest of this file writes no log.
MGQ_Multiplayer::Log.define_singleton_method(:write) { |_message| }

# The log's last line: how the game closes.
MGQ_Multiplayer.module_eval(source[/  def self\.closing_text\(error.*?\n  end\n/m])
error = begin
  raise ArgumentError, "bad"
rescue => e
  e
end
check("the log's last line tells a game that ended from one quit and one an error ended",
      [MGQ_Multiplayer.closing_text(nil), MGQ_Multiplayer.closing_text(SystemExit.new(0)), MGQ_Multiplayer.closing_text(error)[/\A.*bad at /]],
      ["the game closes", "the game closes: it was quit (exit status 0)", "the game closes after an error: ArgumentError: bad at "])
MGQ_Multiplayer.const_set(:ROOM_DRAIN_TOPIC, "world.drain") unless defined?(MGQ_Multiplayer::ROOM_DRAIN_TOPIC)
MGQ_Multiplayer.module_eval(source[/  def self\.closing\(error\)\n.*?\n  end\n/m])
lines = logged_lines { [error, error, nil, nil].each { |ended| MGQ_Multiplayer.closing(ended) } }
check("an error the game's error box shows is written once, though the game's end names it again, and the end itself once",
      lines.map { |line| line[/\A[^:]*/] }, ["the game closes after an error", "the game closes"])

# A name someone else chose: nothing left of it reads as the fallback.
MGQ_Multiplayer.const_set(:MAX_NAME_LENGTH, 32) unless defined?(MGQ_Multiplayer::MAX_NAME_LENGTH)
MGQ_Multiplayer.module_eval(source[/  def self\.clean\(name.*?\n  end\n/m])
check("a name someone else chose that is empty still reads A friend", MGQ_Multiplayer.clean("  "), "A friend")

# The bridges: MGQ Online's stays pinned to Multiplayer.dll's version, whatever the Mod Framework's
# bridge speaks with its own DLL.
newer = FakeBridge.new(2)
framework_lines = []
Mod_Framework::Log.define_singleton_method(:write) { |line| framework_lines << line; nil }
Mod_Framework.bridge.open(newer)
check("a framework DLL of a newer bridge leaves MGQ Online's bridge at its own version",
      [MGQ_Multiplayer::Bridge::VERSION, Mod_Framework.bridge.open?, MGQ_Multiplayer::Bridge.open(FakeBridge.new(1))], [1, false, true])

# The served battles' fingerprint: the CRC of MGQ Online's own scripts, none of the framework's.
framework_scripts = File.read(File.join(FRAMEWORK_DIR, "loader.rbx"), :encoding => "BOM|UTF-8")[/SCRIPTS = %w\[(.*?)\]/m, 1].split
served = File.read(File.join(SCRIPTS_DIR, "battles_served.rbx"), :encoding => "UTF-8")[/  def self\.scripts_fingerprint\n.*?\n  end\n/m]
check("the served scripts' fingerprint reads MGQ Online's own scripts, which name none of the framework's",
      [served.include?("MGQ_Multiplayer::SCRIPTS.map"), scripts & framework_scripts], [true, []])
