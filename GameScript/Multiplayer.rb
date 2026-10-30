#----------------------------------------------------------------
#  Multiplayer.rb
#
#  Changelog:
#      Paulinchen  2026-10-30: Caught, logged and showed the errors of its own load
#                            - Dropped the byte order mark
#      Paulinchen  2026-10-28: Stopped loading coop_story_rewards.rbx, world_catchup_data.rbx and battles_raid_freeze_data.rbx, which the events database and the relay replace
#                            - Handed the story's last writes over and waited for the world room to send them as the game closes
#                            - Wrote how the game closes once its scenes end, since its Main section ends the process before at_exit
#                            - Named the text encodings, since the game has no Encoding constants
#      Paulinchen  2026-10-24: Loaded world_overview_mods.rbx after world_overview_pages.rbx
#                            - Loaded world_gates.rbx after world_difficulty.rbx
#                            - Loaded ui_mod_browser.rbx after ui_bug_report.rbx and named the mp_mod_browser_* exports
#                            - Stopped loading the removed battles_pvp_lobby.rbx
#      Paulinchen  2026-10-23: Dropped the directory exports of the requests and actions the DLL now sends itself, and mp_copy_text
#                            - Dropped the directory exports of the requests and actions the DLL now sends itself
#                            - Dropped the mp_mods_* exports of parked mods, which the parking topics replace
#                            - Dropped mp_mod_hash, mp_mods_install and mp_mods_options, which world_mods.rbx reaches through the bridge
#                            - Dropped mp_world_id and mp_world_directory_id, whose folder ids and invites the DLL keeps
#                            - Read the DLL's texts as text, which the bridge takes
#                            - Dropped Link.take_typed and mp_take_typed, since the text box in C# takes what is typed
#                            - Dropped mp_world_say, mp_world_receive and mp_world_status, since the world room goes through the bridge
#                            - Loaded story_keys.rbx after story_state.rbx, and no longer world_affection.rbx, whose affection the story tracks keep
#                            - Dropped the Raid World story's write, state, checkpoints and route lock, which play on the story tracks
#                            - Told the bridge's frame
#                            - Read and wrote Player.ini and the other ini files through the DLL, which keeps the player key
#                            - Dropped mp_new_id and mp_set_player
#                            - Wrote the scripts' log into the DLL's log of the day through the bridge, and into that file directly while the mod stays off
#                            - Wrote the log's last lines before the game's error box and as the game closes
#                            - Loaded the battle server's core library through Fiddle in Bridge::FiddleBackend
#                            - Dropped mp_mods_list, whose catalog world_mods.rbx takes through the bridge
#                            - Added Bridge, the bridge to C# through mp_bridge_open, mp_call, mp_reply and mp_drain
#                            - Turned the mod on only once the bridge opened
#                            - Sent the staged bridge entries and took the bridge events once a frame
#                            - Stopped loading the deleted battles_pvp_mirror.rbx
#                            - Deleted the log rules of a game started for the options dump
#                            - Deleted the switch that never turned the mod off
#                            - Named mp_memory_usage
#      Paulinchen  2026-10-22: Named mp_dir_open and mp_dir_read
#                            - Named mp_update_rollback, told whether the release to install is a step back and said the version to play for one
#      Paulinchen  2026-10-17: Loaded battles_raid_freeze_data.rbx, battles_raid_freeze.rbx and world_freeze.rbx after battles_raid_pool.rbx
#                            - Loaded ui_raid_freeze.rbx after ui_raid_bar.rbx
#      Paulinchen  2026-10-15: Loaded battles_served.rbx after battles_sync_live.rbx and named the mp_battle_* exports
#                            - Named mp_dir_create with a world's options in one number
#                            - Wrote one log per day and deleted the logs of earlier days
#      Paulinchen  2026-10-13: Loaded ui_single_player.rbx after ui_leader_hud.rbx
#                            - Loaded battles_raid_tiers.rbx after battles_raid_pool.rbx
#                            - Named mp_dir_create and mp_dir_edit with a Classic world's raid bosses
#                            - Named mp_dir_create and mp_dir_edit with a Raid World's squad rules
#      Paulinchen  2026-10-12: Loaded world_affection.rbx after world_catchup_exp.rbx
#                            - Loaded world_overview_pages.rbx after world_overview.rbx
#                            - Read the mouse wheel's notches once a frame through mp_mouse_wheel
#                            - Loaded world_catchup_exp.rbx after world_catchup.rbx
#                            - Loaded ui_leader_hud.rbx after ui_raid_bar.rbx
#                            - Kept a Player.ini that exists but could not be read
#                            - Read ini files with a byte order mark, in UTF-16 or in Latin-1
#                            - Wrote an ini file through a file next to it that replaces it in one step
#                            - Kept and removed several settings of Player.ini in one write and listed settings by prefix
#      Paulinchen  2026-10-11: Cut the session's log to its newest 2 MB once it passes 4 MB
#                            - Loaded ui_bug_report.rbx last and named the mp_report_* exports
#                            - Loaded world_opening.rbx after world_catchup.rbx
#                            - Loaded ui_theme.rbx and ui_layout.rbx after ui.rbx
#                            - Kept the mouse's clicks from the mod's screens while the left Alt is held
#                            - Loaded ui_edge_arrows.rbx after ui_party_box.rbx
#      Paulinchen  2026-10-10: Named mp_dev_build
#                            - Loaded ui_raid_bar.rbx after ui_party_box.rbx
#                            - Loaded coop_teleport.rbx after coop_gather.rbx
#                            - Retried a text export with a larger buffer when the text grew meanwhile
#      Paulinchen  2026-10-09: Named the mp_mods_* exports of parked mods and mp_dir_create and mp_dir_edit with mod parking
#                            - Loaded world_mods_parking.rbx after world_mods.rbx
#                            - Loaded story_state.rbx before coop_story.rbx
#                            - Loaded world_difficulty.rbx after world_catchup.rbx
#                            - Named mp_dir_create and mp_dir_edit with a Raid World's difficulty
#                            - Named the mp_raid_boss* exports
#                            - Loaded battles_raid_pool.rbx after battles_coop_hotjoin.rbx
#                            - Loaded world_catchup_data.rbx before world_story.rbx
#                            - Loaded world_catchup.rbx after world_story.rbx
#                            - Loaded battles_coop_join.rbx after battles_coop_hotjoin.rbx
#      Paulinchen  2026-10-08: Loaded coop_scope.rbx after coop.rbx
#                            - Loaded world_story.rbx after coop_story.rbx and world.rbx and named the mp_raid_* exports
#                            - Loaded battles_raid_bosses.rbx before battles_coop.rbx and battles_coop_hotjoin.rbx after it
#                            - Named mp_dir_create with the world's type and companion sharing
#                            - Told whether a key or the left mouse button is held
#                            - Took a key nobody asked about in the frame before as let go
#                            - Named mp_update_game and told the player to pick Multiplayer to update
#                            - Told a watched key's press frame by frame
#                            - Counted the frames for Key.pressed? at Graphics.update
#                            - Counted the sessions kept by the scripts' logs alone
#                            - Deleted no logs in a game started for the options dump
#                            - Counted only the old logs actually deleted, and logged those that could not be
#      Paulinchen  2026-10-07: Named mp_world_say
#                            - Kept the logs of the last five game sessions
#                            - Logged the hooks as one line per script
#                            - Logged how the game closes and each F12 reset
#                            - Kept the press that closes a screen of the mod from reaching the game
#                            - Gave the background wrap its script
#                            - Named every export of the DLL with its signature once in Link
#                            - Loaded coop_choices.rbx after the world screen
#                            - Wrote the in-game log into a file per game session
#                            - Logged the start, scripts, Discord mod, update gate, buttons, name and PvP link steps
#                            - Forgot the chosen name when the player clears it
#      Paulinchen  2026-10-06: Kept the buttons held while any screen of the mod holds them
#                            - Guarded Input through core_hooks.rbx
#                            - Kept up to 3000 log lines per session, counted repeated lines and moved a large log aside
#                            - Loaded coop_story_rewards.rbx before coop_story.rbx
#                            - Handed a Discord invite into a world to world.rbx instead of the PvP connection
#                            - Kept the last name Discord told
#                            - Wrote the in-game log as Multiplayer InGame.log into the game folder's Logs folder
#                            - Loaded trade.rbx and ui_trade.rbx after battles_team.rbx
#                            - Told whether a button is held past the capture
#                            - Loaded ui_wheel.rbx before ui_actions.rbx
#                            - Loaded world_mods.rbx after world.rbx
#      Paulinchen  2026-10-04: Loaded battles_coop_level_sync.rbx after battles_coop.rbx
#                            - Loaded ui_party_box.rbx after world_overview.rbx
#                            - Loaded ui_emotes.rbx after ui_chat.rbx
#                            - Loaded coop_scene.rbx after coop_gather.rbx
#                            - Loaded coop_gather.rbx and coop_castle.rbx, split out of coop_events.rbx
#                            - Loaded the scripts by their new names
#                            - Loaded ui_text_box.rbx after ui.rbx, and world_save_distribution.rbx after world.rbx
#      Paulinchen  2026-10-03: Loaded battles_pvp_backline.rbx after battles_pvp.rbx
#                            - Loaded battles_balance_pvp.rbx before battles_pvp.rbx
#                            - Loaded core_game_access.rbx after core_hooks.rbx
#                            - Loaded ui.rbx, and the scripts split off the world, battle sync and PvP scripts
#                            - Loaded core_log.rbx first
#                            - Loaded ui_notices.rbx last
#                            - Loaded core_hotkeys.rbx, renamed from mp_keys.rbx
#      Paulinchen  2026-10-02: Loaded mp_keys.rbx after core_hooks.rbx, and kept other settings in Player.ini besides the name
#                            - Loaded world_save_export.rbx after world.rbx
#                            - Loaded core_hooks.rbx first and followed Graphics.update and SceneManager.run through it
#      Paulinchen  2026-10-01: Loaded coop_squad.rbx after coop.rbx
#                            - Loaded battles_duel.rbx and battles_team.rbx after the PvP battles, and world_overview.rbx last
#                            - Added Mouse
#      Paulinchen  2026-09-30: Loaded the other scripts from Patch/Multiplayer/Scripts
#                            - Loaded ui_chat.rbx after the action wheel
#                            - Loaded coop.rbx before the party scripts that register with it
#                            - Loaded overworld_sync.rbx before the scripts that register with it
#                            - Moved the mod folder into Patch/Multiplayer and loaded the scripts in a fixed order
#                            - Called the battle and party scripts by their new names
#                            - Named the mod Monster Girl Quest! Online in the update message
#                            - Asked GitHub for a newer release and disabled worlds and PvP once one is out
#                            - Read held buttons past the capture too
#      Paulinchen  2026-09-29: Said in $mgq_text_input while the player types
#                            - Added Capture
#                            - Told whether the game's window is hooked
#                            - Told the DLL the player's key and name for worlds, and read typing from the keyboard through it
#                            - Added Player, the player's id and name
#                            - Found the mod folder relative to the game's folder
#                            - Hosted without a port, since games meet at the relay
#                            - Added Link.status
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# What every way of playing together shares: the connection with a friend through
# Patch/Multiplayer/Multiplayer.dll, the game running on while its window is in the background,
# keys the game's own Input does not know, and the Discord mod, when it is installed. It also loads
# the mod's other scripts, see SCRIPTS.
module MGQ_Multiplayer
  # Folder inside the game's Patch folder that holds the DLL, the other scripts and everything the
  # mod writes but its logs.
  MOD_DIR = "Patch\\Multiplayer"

  # Folder in the game folder that holds the logs, shared with the user's other mods.
  LOG_DIR = "Logs"

  # Folder of the other scripts inside the mod folder.
  SCRIPTS_DIR = "Scripts"

  # The mod's other scripts in SCRIPTS_DIR, in the order they load.
  #
  # A script may use only what loaded before it while it loads, such as core_log.rbx, which gives
  # every script its log, core_actors.rbx's Game_MpActor, or core_hooks.rbx, overworld_sync.rbx and
  # coop.rbx, which the scripts after them register with. The battle scripts install their battle
  # hooks once the game runs, the last loaded first, so their order decides how those hooks wrap
  # each other.
  SCRIPTS = %w[
    core_log core_hooks core_game_access core_hotkeys ui ui_theme ui_layout ui_text_box core_actors core_async overworld_sync ui_wheel ui_actions ui_chat ui_emotes overworld
    coop coop_scope coop_squad coop_events coop_gather coop_teleport coop_scene coop_npcs story_state story_keys coop_story coop_castle
    world world_mods world_mods_parking world_story world_catchup world_catchup_exp world_opening world_difficulty world_gates world_save_distribution world_text world_screen world_save_export coop_choices
    battles battles_raid_bosses battles_coop battles_coop_hotjoin battles_coop_join battles_raid_pool battles_raid_freeze world_freeze battles_raid_tiers battles_coop_level_sync
    battles_sync battles_sync_wire battles_sync_recorder battles_sync_playback battles_sync_live battles_served
    battles_balance_pvp battles_pvp battles_pvp_backline battles_duel battles_team
    trade ui_trade
    world_overview world_overview_pages world_overview_mods ui_party_box ui_edge_arrows ui_raid_bar ui_raid_freeze ui_leader_hud ui_single_player ui_notices ui_bug_report ui_mod_browser
  ]

  # Extension of the scripts, which the mod loader skips, since only this script may load them.
  SCRIPT_EXTENSION = ".rbx"

  # File name of the DLL inside the mod folder.
  DLL = "Multiplayer.dll"

  # Frames between two hand-overs to the Discord mod, half a second at 60 frames per second.
  DISCORD_FRAMES = 30

  # Longest player name shown.
  MAX_NAME_LENGTH = 32

  # What the game says wherever the player tries to use the mod once a newer release is out.
  UPDATE_MESSAGE = "A Monster Girl Quest! Online update is out. Pick Multiplayer on the title screen to update."

  # What the game says there instead once the release to play is older than this one, its version
  # filled in.
  ROLLBACK_MESSAGE = "Monster Girl Quest! Online %s is the version to play now. Pick Multiplayer on the title screen to install it."

  # The bridge topic that waits until the world room sent what the scripts handed it, as the game
  # closes (WorldRoomTopics in the DLL).
  ROOM_DRAIN_TOPIC = "world.drain"

  # Tells whether the mod can run.
  #
  # @return [Boolean] Whether the mod is on, its DLL is in the mod folder and the bridge to it
  #   opened, which a stand-in DLL, an older one or one of another bridge version never lets happen.
  def self.available?
    @available == true
  end

  # Starts the DLL, opens the bridge to it and keeps the game running in the background, once per
  # game session.
  def self.start
    return if @started
    @started = true
    Log.write("Monster Girl Quest! Online starting on Ruby #{RUBY_VERSION}")
    @available = open_dll
    Log.settle(@available)
    return unless @available

    Background.start
    UpdateCheck.start
  rescue => e
    Log.write("start failed: #{e.class}: #{e.message}")
    Log.settle(available?)
  end

  # Starts the DLL and opens the bridge to it.
  #
  # @return [Boolean] Whether the bridge opened; the log tells why not.
  def self.open_dll
    unless File.exist?(path(DLL))
      Log.write("not started: #{path(DLL)} is missing")
      return false
    end

    Link.start
    return false unless Bridge.start(path(DLL))

    Log.write("started #{path(DLL)}")
    true
  rescue => e
    Log.write("start failed: #{e.class}: #{e.message}")
    false
  end

  # Writes how the game closes, once per ending, hands the story's last writes over and waits for
  # the world room to send them, and has the DLL write every line at once, so neither the game's
  # error box nor its end loses the last ones.
  #
  # @param error [Exception, nil] What ends the game, nil when it ends without one.
  def self.closing(error)
    Log.write(closing_text(error)) unless @closed_by && @closed_by[0].equal?(error)
    @closed_by = [error]
    MGQ_MpStoryKeys.flush if defined?(MGQ_MpStoryKeys)
    Log.hand_over
    Bridge.call(ROOM_DRAIN_TOPIC)
    Log.flush
  end

  # Runs the game's scenes to their end and writes how the game closes while it still runs: on a
  # quit the scenes return, the window closing or an error throws out of them, and after each the
  # game's Main section (the WF-RGSS Exit-EX plugin) ends the process through ExitProcess, which
  # runs no at_exit.
  #
  # @param original [Proc] Runs SceneManager.run.
  # @return [Object] What it returns.
  def self.run_game(original)
    result = original.call
  rescue Exception => e
    closing(e) unless reset?(e)
    raise
  else
    closing(nil)
    result
  end

  # Tells whether an error is the game's reset by F12, which starts its scenes again and ends
  # nothing.
  #
  # @param error [Exception] The error.
  # @return [Boolean] Whether it is.
  def self.reset?(error)
    defined?(RGSSReset) && error.is_a?(RGSSReset) ? true : false
  end

  # Tells whether another release of the mod is the one to play, a newer one or a step back the
  # relay asks for, which MGQ_MpWorld and MGQ_MpBattlesPvp disable themselves for, so two games
  # speaking a protocol a refactor changed never meet.
  #
  # @return [Boolean] Whether one was found.
  def self.outdated?
    !UpdateCheck.version.nil?
  end

  # Tells how the game closes, for the log's last line, without which a log that just stops cannot
  # tell a game closed from one that crashed.
  #
  # @param error [Exception, nil] What ends the game, $! as it closes; nil when it ends without one.
  # @return [String] The line.
  def self.closing_text(error)
    return "the game closes" if error.nil?
    return "the game closes: it was quit (exit status #{error.status})" if error.is_a?(SystemExit)

    "the game closes after an error: #{error.class}: #{error.message.to_s[0, 200]} at #{Array(error.backtrace).first}"
  end

  # Notes that the game's scenes start running, which only F12 makes happen a second time.
  def self.note_run
    @runs = @runs.to_i + 1
    Log.write("F12 reset the game: its scenes start again from the title (run #{@runs}), the mod keeps its hooks and state") if @runs > 1
  end

  # Reads the version of the release to install, once the check found one.
  #
  # @return [String, nil] The version, nil until one was found.
  def self.newer_version
    UpdateCheck.version
  end

  # Tells whether the release to install is older than this one, a step back the relay asks for.
  #
  # @return [Boolean] Whether it is.
  def self.rollback?
    UpdateCheck.rollback?
  end

  # Tells what the game says wherever the player tries to use the mod while another release is the
  # one to play.
  #
  # @return [String] UPDATE_MESSAGE, or ROLLBACK_MESSAGE for a step back.
  def self.update_message
    rollback? ? format(ROLLBACK_MESSAGE, newer_version) : UPDATE_MESSAGE
  end

  # Builds the path of a file inside the mod folder, relative to the game's folder.
  #
  # An absolute path breaks in a folder named with characters outside ASCII, such as the
  # untranslated game's, since File takes it only as UTF-8 and Win32API loads a DLL only from the
  # system's code page; the game always runs in its own folder, so a relative one works for both.
  #
  # @param name [String] The file name, relative to the mod folder.
  # @return [String] The path.
  def self.path(name)
    "#{MOD_DIR}\\#{name}"
  end

  # Builds the path of a log file in the game folder's Logs folder, which holds the logs of every
  # mod, and makes the folder when it is missing.
  #
  # @param name [String] The log's file name.
  # @return [String] The path, relative to the game folder.
  def self.log_path(name)
    Dir.mkdir(LOG_DIR) unless File.directory?(LOG_DIR)
    "#{LOG_DIR}\\#{name}"
  end

  # Loads the mod's other scripts in the order of SCRIPTS. One that is missing or fails is logged,
  # and the others load all the same.
  def self.load_scripts
    failed = []
    SCRIPTS.each do |name|
      file = path("#{SCRIPTS_DIR}\\#{name}#{SCRIPT_EXTENSION}")
      begin
        eval(File.read(file, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, file)
      # A script that does not parse raises a SyntaxError, which is no StandardError.
      rescue Exception => e
        failed << name
        Log.write("#{name}#{SCRIPT_EXTENSION} did not load: #{e.class}: #{e.message} (#{e.backtrace.to_a.first})")
      end
    end
    MGQ_MpHooks.report if defined?(MGQ_MpHooks)
    Log.write("loaded #{SCRIPTS.size - failed.size} of #{SCRIPTS.size} scripts#{failed.empty? ? '' : ", not #{failed.join(', ')}"}")
  end

  # Writes what failed as this file loaded into the log at once and shows it in the game's message
  # box, the first time only.
  #
  # Nothing else would write the log: the start may not have settled it, and the hooks that write
  # it each frame and as the game closes may be missing.
  #
  # @param stage [String] What failed, such as "loading".
  # @param error [Exception] The error.
  def self.load_failed(stage, error)
    line = "#{stage} FAILED: #{error.class}: #{error.message} (#{Array(error.backtrace).first})"
    Log.write(line)
    Log.settle(available?)
    Log.flush
    return if @load_failed

    @load_failed = true
    msgbox("Monster Girl Quest! Online failed to load.") if respond_to?(:msgbox, true)
  rescue Exception
    nil
  end

  # Keeps a name someone else chose short, on one line and free of message codes.
  #
  # @param name [String, nil] The name.
  # @param fallback [String] What stands in when nothing is left of it.
  # @return [String] The name, the fallback when nothing is left of it.
  def self.clean(name, fallback = "A friend")
    cleaned = name.to_s.gsub(/[\x00-\x1f\\]/, "").strip[0, MAX_NAME_LENGTH]
    cleaned.empty? ? fallback : cleaned
  rescue
    fallback
  end

  # The scripts' log: each line goes to the DLL's log of the day, Logs/Multiplayer <day>.log, which
  # holds the DLL's lines too, through the bridge, staged with the rest of the frame. Lines written
  # before the bridge opens wait for it; while the mod stays off, the scripts write them into that
  # file themselves, so the reason shows.
  module Log
    # The topic of one line, [time of day, line], see ScriptLog.cs.
    TOPIC = "log.write"

    # The topic that writes every line handed over at once.
    FLUSH_TOPIC = "log.flush"

    # How the time of day starts each line.
    TIME = "%H:%M:%S"

    # The most lines kept while the bridge has not opened yet.
    EARLY_LINES = 1000

    # The file the scripts write while the mod stays off, named after the day as the DLL names it.
    OWN_FILE = "Multiplayer %s.log"

    # How the day shows in OWN_FILE.
    STAMP = "%Y-%m-%d"

    # What starts each line in OWN_FILE, as the DLL starts the scripts' lines (ScriptLog.Mark).
    MARK = "[script] "

    # The encodings a line crosses the bridge in as text; any other crosses as its bytes.
    # Named, since the Encoding constants are missing in the game.
    TEXT_ENCODINGS = [Encoding.find("UTF-8"), Encoding.find("US-ASCII")]

    # The lines written before the bridge opened, each [time, line]; nil once handed over.
    @early = []

    # The path of OWN_FILE once the mod stays off, nil while the lines go to the DLL.
    @own_file = nil

    # Appends a line, stamped with the time of day.
    #
    # @param message [String] The line to append.
    def self.write(message)
      line = [Time.now.strftime(TIME), plain(message.to_s)]
      if @early
        @early << line if @early.size < EARLY_LINES
      elsif @own_file
        append(line)
      else
        Bridge.stage(TOPIC, line)
      end
      nil
    rescue
      nil
    end

    # Hands the lines written so far over once the start decided: to the DLL when the bridge
    # opened, else into OWN_FILE, where every later line goes too. Only the first call acts.
    #
    # @param open [Boolean] Whether the bridge opened.
    def self.settle(open)
      lines = @early
      return unless lines

      @early = nil
      if open
        lines.each { |line| Bridge.stage(TOPIC, line) }
      else
        @own_file = MGQ_Multiplayer.log_path(format(OWN_FILE, Time.now.strftime(STAMP)))
        lines.each { |line| append(line) }
      end
    rescue
      nil
    end

    # Hands every line over at once and has the DLL write them, with how often the last line
    # repeated, as the game closes or stops on an error.
    def self.flush
      return settle(false) if @early
      return if @own_file

      hand_over
      Bridge.call(FLUSH_TOPIC)
      nil
    rescue
      nil
    end

    # Hands the lines written so far to the DLL at once instead of with the frame, such as before
    # a bug report reads the log.
    def self.hand_over
      Bridge.flush unless @early || @own_file
      nil
    rescue
      nil
    end

    # Appends a line to OWN_FILE.
    #
    # @param line [Array<String>] The time and the line.
    def self.append(line)
      File.open(@own_file, "ab") { |file| file.write("#{line[0]}  #{MARK}#{line[1]}\r\n") }
    end

    # Makes a line one that crosses the bridge.
    #
    # @param text [String] The line.
    # @return [String] The line, or its bytes when it is no valid text, such as one built from bytes
    #   the DLL handed over.
    def self.plain(text)
      TEXT_ENCODINGS.include?(text.encoding) && text.valid_encoding? ? text : text.dup.force_encoding("ASCII-8BIT")
    end
  end

  # Files of key=value lines other than Player.ini, such as a world's world.ini, which the DLL reads
  # and writes (IniFile.cs).
  module Ini
    # The topic that reads a file.
    READ_TOPIC = "ini.read"

    # The topic that writes a file.
    WRITE_TOPIC = "ini.write"

    # Reads a file.
    #
    # @param path [String] The file, relative to the game's folder.
    # @return [Hash] The values by key, empty when the file is missing or unreadable.
    def self.read(path)
      load(path) || {}
    end

    # Reads a file, telling one that could not be read from one that is missing.
    #
    # @param path [String] The file, relative to the game's folder.
    # @param quiet [Boolean] Whether a file that could not be read goes unlogged, as when it failed
    #   just before.
    # @return [Hash, nil] The values by key, empty when the file is missing; nil when it exists but
    #   could not be read, or while the bridge is closed.
    def self.load(path, quiet = false)
      values = Bridge.call(READ_TOPIC, "path" => path.to_s, "quiet" => quiet ? true : false)
      values.is_a?(Hash) ? values : nil
    end

    # Writes a file, replacing it in one step, so a crash or a full disk never leaves it half
    # written.
    #
    # @param path [String] The file, relative to the game's folder.
    # @param values [Hash] The values by key, each kept on its line.
    # @return [Boolean] Whether the file was written.
    def self.write(path, values)
      lines = {}
      values.each { |key, value| lines[key.to_s] = value.to_s }
      Bridge.call(WRITE_TOPIC, "path" => path.to_s, "values" => lines) == true
    end
  end

  # Who plays this game, kept in Patch/Multiplayer/Player.ini with every setting of the scripts,
  # which only the DLL reads and writes (PlayerIni.cs); the player key never leaves it. This keeps
  # the settings as the DLL last answered them, since some are read every frame.
  module Player
    # Seconds before the settings are asked again while Player.ini cannot be read, which a lock by
    # an antivirus or a cloud sync is usually gone after.
    RETRY_SECONDS = 1

    # Setting that keeps the last name Discord told.
    DISCORD_NAME = "discord_name"

    # The topic that answers the settings as they stand.
    STATE_TOPIC = "player.state"

    # The topic that keeps and removes settings.
    CHANGE_TOPIC = "player.change"

    # The topic that takes the name Discord tells.
    DISCORD_TOPIC = "player.discord"

    # The topic that takes the name the player chose.
    NAME_TOPIC = "player.name"

    # The topic that tells the worlds who plays.
    SHARE_TOPIC = "player.share"

    # What the settings are while the DLL has not answered: none, and Player.ini not read.
    NONE = { "values" => {}.freeze, "readable" => false, "notice" => nil, "name" => nil }.freeze

    # Reads the name the others see: the one the player chose for Multiplayer, or else their name on
    # Discord, or the last one Discord told while it has not told one yet.
    #
    # @return [String, nil] The name, nil while the player chose none and Discord never told one.
    def self.name
      tell_discord_name
      state["name"]
    end

    # Keeps the name the player chose, which replaces their name on Discord; an empty one forgets
    # the chosen name, so the name on Discord stands again. The worlds are told who plays then.
    #
    # @param name [String] The name.
    def self.name=(name)
      take(Bridge.call(NAME_TOPIC, name.to_s))
    end

    # Reads a setting of Player.ini, such as a key the player bound.
    #
    # @param key [String] The setting.
    # @return [String, nil] Its value, nil while it is not set.
    def self.setting(key)
      state["values"][key]
    end

    # Lists the settings whose keys start with a prefix, such as the favourite worlds.
    #
    # @param prefix [String] What their keys start with.
    # @return [Array<String>] The rest of each key after the prefix, in the order Player.ini keeps
    #   them.
    def self.keys_under(prefix)
      state["values"].keys.select { |key| key.start_with?(prefix) }.map { |key| key[prefix.size..-1] }
    end

    # Keeps a setting in Player.ini.
    #
    # @param key [String] The setting.
    # @param value [Object] Its value.
    # @return [Boolean] Whether Player.ini was written.
    def self.store(key, value)
      change(key => value.to_s)
    end

    # Removes a setting from Player.ini.
    #
    # @param key [String] The setting.
    # @return [Boolean] Whether Player.ini was written.
    def self.forget(key)
      change(key => nil)
    end

    # Keeps and removes settings of Player.ini in one write. A setting kept moves to the end of the
    # file, so a list such as the hidden worlds added reads back the oldest first.
    #
    # @param changes [Hash] The values by setting, nil for one to remove.
    # @return [Boolean] Whether Player.ini was written.
    def self.change(changes)
      plain = {}
      changes.each { |key, value| plain[key.to_s] = value.nil? ? nil : value.to_s }
      answer = take(Bridge.call(CHANGE_TOPIC, plain))
      answer ? answer["written"] == true : false
    end

    # Tells whether Player.ini was read, or is missing, so its settings are known.
    #
    # @return [Boolean] Whether they are.
    def self.readable?
      state["readable"] == true
    end

    # Takes the notice that Player.ini cannot be read, once a session and only while a write was
    # turned down for it.
    #
    # @return [String, nil] The notice, nil when there is none to show.
    def self.take_notice
      notice = state["notice"]
      return nil if @noticed || notice.nil?

      @noticed = true
      notice
    end

    # Tells the worlds who plays, once the player has a name.
    #
    # @return [Boolean] Whether the DLL knows who plays.
    def self.share
      answer = take(Bridge.call(SHARE_TOPIC))
      answer ? answer["shared"] == true : false
    end

    # Hands the DLL the name Discord tells, when it changed.
    def self.tell_discord_name
      discord = Discord.player_name.to_s
      return if discord.empty? || discord == @discord_name

      @discord_name = discord
      take(Bridge.call(DISCORD_TOPIC, discord))
    end

    # Gives the settings as the DLL last answered them, asking it the first time and again at most
    # every RETRY_SECONDS while Player.ini cannot be read.
    #
    # @return [Hash] "values", "readable", "notice" and "name", see PlayerIni.cs; NONE while the DLL
    #   has not answered.
    def self.state
      return @state if @state && @state["readable"]
      return @state || NONE if @asked_at && Time.now - @asked_at < RETRY_SECONDS

      @asked_at = Time.now
      take(Bridge.call(STATE_TOPIC))
      @state || NONE
    end

    # Keeps what a topic answered as the settings.
    #
    # @param answer [Hash, nil] The answer, nil while the bridge is closed.
    # @return [Hash, nil] The answer.
    def self.take(answer)
      @state = answer if answer.is_a?(Hash)
      answer
    end
  end

  # Patch/Multiplayer/Multiplayer.dll's functions: hosting, joining, the first exchange of what each
  # game hands over, and the messages that follow, all running on threads of the DLL's own.
  module Link
    # Bytes the DLL may write the connection's state into at first, a PvP battle's team included.
    # A larger state asks for a larger buffer.
    STATE_SIZE = 70_000

    # Bytes the DLL may write the connection's state without the friend's team into at first.
    STATUS_SIZE = 1_024

    # Bytes the DLL may write a message into at first. A larger message asks for a larger buffer.
    MESSAGE_SIZE = 4_096

    # The arguments of an export that writes a text into a buffer, see read: the buffer and its size.
    READ_ARGUMENTS = 'pl'

    # Times read asks again with a larger buffer, the first time and three more when the text grew
    # again between asking its size and copying it.
    READ_TRIES = 4

    # Every export of the DLL with its arguments in Win32API notation, 'v' for none; each returns a
    # long. A call names the export alone, so a changed signature is followed here once.
    EXPORTS = {
      # The DLL itself, the player and the update check.
      'mp_start' => 'v',
      'mp_keep_running' => 'v',
      'mp_check_for_update' => 'v',
      'mp_newer_version' => READ_ARGUMENTS,
      'mp_set_player_name' => 'p',
      'mp_player_id' => READ_ARGUMENTS,
      'mp_restart_game' => 'v',
      'mp_update_game' => 'v',
      'mp_update_rollback' => 'v',
      'mp_dev_build' => 'v',
      'mp_memory_usage' => READ_ARGUMENTS,

      # The keyboard, the clipboard and the mouse wheel.
      'mp_typing' => 'l',
      'mp_copy_code' => 'v',
      'mp_mouse_wheel' => 'v',

      # The PvP connection.
      'mp_host' => 'pp',
      'mp_join_invite' => 'pp',
      'mp_join_clipboard' => 'pp',
      'mp_receive_invite' => 'p',
      'mp_cancel' => 'v',
      'mp_send' => 'p',
      'mp_receive' => READ_ARGUMENTS,
      'mp_state' => READ_ARGUMENTS,
      'mp_status' => READ_ARGUMENTS,

      # The world directory.
      'mp_dir_watch' => 'p',
      'mp_dir_refresh' => 'v',
      'mp_dir_open' => 'p',
      'mp_dir_list' => READ_ARGUMENTS,

      # The world's room.
      'mp_world_open' => 'p',
      'mp_world_close' => 'v',
      'mp_world_send' => 'lp',

      # The Mods screen of the title screen.
      'mp_mod_browser_refresh' => 'v',
      'mp_mod_browser_list' => READ_ARGUMENTS,
      'mp_mod_browser_apply' => 'p',
      'mp_mod_browser_open_page' => 'p',
      'mp_mod_browser_details' => 'p',

      # The mods a world that turns other mods off does not name, parked outside Patch.

      # Trades.
      'mp_trade_commit' => 'pppp',
      'mp_trade_cancel' => 'pp',
      'mp_trade_state' => READ_ARGUMENTS,
      'mp_trade_done' => 'pp',
      'mp_trade_pending' => 'p',
      'mp_trade_pending_list' => READ_ARGUMENTS,

      # A Raid World's shared companions at the relay.
      'mp_raid_story_fetch' => 'p',
      'mp_raid_story_headers' => READ_ARGUMENTS,
      'mp_raid_companions_add' => 'pp',

      # A Raid World's boss pools at the relay.
      'mp_raid_bosses_fetch' => 'p',
      'mp_raid_boss_report' => 'pppp',
      'mp_raid_boss_state' => READ_ARGUMENTS,

      # A co-op battle the battle server hosts, and its battle channel.
      'mp_battle_serve' => 'pppp',
      'mp_battle_open' => 'pp',
      'mp_battle_send' => 'lp',
      'mp_battle_receive' => READ_ARGUMENTS,
      'mp_battle_state' => READ_ARGUMENTS,
      'mp_battle_close' => 'v',

      # Bug reports.
      'mp_report_snap' => 'pll',
      'mp_report_drop_snap' => 'v',
      'mp_report_send' => 'ppppl',
      'mp_report_state' => READ_ARGUMENTS,
    }

    # Finds the mod folder and starts the DLL's log.
    def self.start
      function('mp_start').call
    end

    # Keeps the game running while another application is active.
    #
    # @return [Boolean] Whether the game keeps running.
    def self.keep_running
      function('mp_keep_running').call == 1
    end

    # Starts hosting.
    #
    # @param game [String] What tells this game version's data from another's.
    # @param payload [String] What the friend gets, such as the player's team.
    def self.host(game, payload)
      Discord.share_player_name
      Log.write("PvP: hosting, handing over #{payload.bytesize} bytes")
      function('mp_host').call(game + "\0", payload + "\0")
    end

    # Joins the host of the invite that is waiting.
    #
    # @param game [String] What tells this game version's data from another's.
    # @param payload [String] What the friend gets, such as the player's team.
    def self.join_invite(game, payload)
      Discord.share_player_name
      Log.write("PvP: joining the host of the waiting invite, handing over #{payload.bytesize} bytes")
      function('mp_join_invite').call(game + "\0", payload + "\0")
    end

    # Joins the host whose join code is on the clipboard.
    #
    # @param game [String] What tells this game version's data from another's.
    # @param payload [String] What the friend gets, such as the player's team.
    def self.join_clipboard(game, payload)
      Discord.share_player_name
      Log.write("PvP: joining the host whose join code is on the clipboard, handing over #{payload.bytesize} bytes")
      function('mp_join_clipboard').call(game + "\0", payload + "\0")
    end

    # Keeps the join code of an invite the player accepted in Discord, until they join with it.
    #
    # @param join_code [String] The join code.
    def self.receive_invite(join_code)
      function('mp_receive_invite').call(join_code + "\0")
    end

    # Tells the DLL the player's name, which the friend sees.
    #
    # @param name [String] The name.
    def self.set_player_name(name)
      function('mp_set_player_name').call(name + "\0")
    end

    # Reads the id everyone sees for the player, as the world directory lists it.
    #
    # @return [String] The id, "" before the player was set.
    def self.player_id
      read('mp_player_id', 64)
    end

    # Starts or stops taking what the player types on the keyboard, and says so in
    # $mgq_text_input, which other mods' hotkeys read from Windows check, since the capture of
    # the game's Input cannot reach them.
    #
    # @param on [Boolean] Whether to take it.
    def self.typing(on)
      Log.write(on ? "keyboard typing on" : "keyboard typing off") if on != $mgq_text_input
      $mgq_text_input = on
      function('mp_typing').call(on ? 1 : 0)
    end

    # Stops hosting or joining, closes the link, forgets what arrived, and turns down a waiting invite
    # unless a team had arrived.
    def self.cancel
      Log.write("PvP: cancelled hosting or joining, the link closes")
      function('mp_cancel').call
    end

    # Puts the join code on the clipboard again.
    #
    # @return [Boolean] Whether the clipboard holds the join code again.
    def self.copy_code
      function('mp_copy_code').call == 1
    end

    # Sends a message to the friend.
    #
    # @param text [String] The message.
    # @return [Boolean] false without an open link, or when the message is too long.
    def self.post(text)
      function('mp_send').call(text + "\0") == 1
    end

    # Takes the oldest message from the friend.
    #
    # @return [String, nil] The message, nil while none waits.
    def self.next_message
      text = read('mp_receive', MESSAGE_SIZE)
      text.empty? ? nil : text.force_encoding("UTF-8")
    end

    # Reads how the connection stands.
    #
    # @return [Hash] "state" ("idle", "hosting", "joining", "received" or "failed") and whichever
    #   of "code", "invite", "error", "opponent", "link" ("open", "closed" or "dropped"), "role"
    #   ("host" or "guest") and "party" apply, what the friend handed over under :payload.
    def self.state
      text = read('mp_state', STATE_SIZE)
      text.empty? ? { "state" => "idle", :payload => "" } : parse(text)
    end

    # Reads how the connection stands without what the friend handed over, cheap enough for checks
    # many times a second.
    #
    # @return [Hash] See state, with an empty :payload.
    def self.status
      text = read('mp_status', STATUS_SIZE)
      text.empty? ? { "state" => "idle", :payload => "" } : parse(text)
    end

    # Reads the DLL's description of the connection: key=value lines, an empty line, the payload.
    #
    # @param text [String] The description.
    # @return [Hash] See state.
    def self.parse(text)
      head, payload = text.force_encoding("UTF-8").split("\n\n", 2)
      state = { :payload => payload.to_s }

      head.to_s.split("\n").each do |line|
        key, value = line.split("=", 2)
        state[key] = value if value
      end

      state
    end

    # Calls an export that writes a text into a buffer, again with a larger buffer when asked for
    # one, READ_TRIES times at most.
    #
    # @param name [String] The export, one that takes READ_ARGUMENTS.
    # @param size [Integer] The buffer's size at first.
    # @return [String] The text as bytes, "" when there is none or it outgrew every buffer.
    def self.read(name, size)
      buffer = "\0" * size
      length = function(name).call(buffer, buffer.size)
      tries = 0

      while length < 0 && tries < READ_TRIES
        tries += 1
        buffer = "\0" * (1 - length)
        length = function(name).call(buffer, buffer.size)
      end

      # The DLL wrote bytes past Ruby's back, so only a binary string counts them right; they are its
      # UTF-8 text, which the bridge takes only as text.
      length > 0 ? buffer.force_encoding("ASCII-8BIT")[0, length].force_encoding("UTF-8") : ""
    end

    # Loads an export of the DLL, with the arguments EXPORTS names for it.
    #
    # @param name [String] The exported function, a key of EXPORTS.
    # @return [Win32API] The function, loaded once.
    def self.function(name)
      @functions ||= {}
      @functions[name] ||= Win32API.new(MGQ_Multiplayer.path(DLL), name, EXPORTS.fetch(name), 'l')
    end
  end

  # The bridge to C# (MGQOnline.Bridge): named topics the DLL answers, with plain values crossing
  # as Marshal through four exports. A script calls a topic for its value, stages what it hands
  # over during a frame, and takes the DLL's events in the handlers it registered; once a frame the
  # staged entries go over in one batch call and the events come back in one drain. Plain values
  # are nil, true, false, Integer, String (UTF-8, US-ASCII or binary), Array and Hash with String
  # or Integer keys; the DLL refuses anything else, such as a Symbol or a game object.
  module Bridge
    # The bridge version these scripts speak, BridgeHost.Version in C#; a DLL of another refuses
    # the handshake.
    VERSION = 1

    # Bytes of the reply buffer at first; a larger reply grows it for good.
    REPLY_SIZE = 4_096

    # Bytes of the drain buffer at first; a larger drain grows it for good.
    DRAIN_SIZE = 16_384

    # The topic the DLL runs a frame's staged entries through, in order.
    BATCH = "batch"

    # The largest frame the drain passes, the most a Win32API long holds; the count starts again
    # from 0 past it.
    MAX_FRAME = 0x7fff_ffff

    # What a call without a request hands over: an empty request, which C# reads as nil.
    NO_REQUEST = ""

    # What call! raises for a topic that answered an error, or while the bridge is closed.
    class Error < StandardError; end

    # Reaches the DLL through the game's Win32API.
    class Win32Backend
      # The four exports with their arguments in Win32API notation; each returns a long.
      SIGNATURES = {
        'mp_bridge_open' => 'lpl',
        'mp_call' => 'lpplpl',
        'mp_reply' => 'lpl',
        'mp_drain' => 'llpl',
      }

      # Loads the four exports.
      #
      # @param path [String] The DLL's path, relative to the game's folder.
      # @raise [RuntimeError] The DLL lacks one of them, as an older build does.
      def initialize(path)
        @functions = {}
        SIGNATURES.each { |name, arguments| @functions[name] = Win32API.new(path, name, arguments, 'l') }
      end

      # Shakes hands (mp_bridge_open).
      #
      # @param version [Integer] The scripts' VERSION.
      # @param reply [String] The reply buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none, or the size needed negated.
      def open(version, reply, size)
        @functions['mp_bridge_open'].call(version, reply, size)
      end

      # Runs a topic (mp_call).
      #
      # @param context [Integer] The context from the handshake.
      # @param topic [String] The topic, null-terminated.
      # @param request [String] The request as Marshal, empty for nil.
      # @param length [Integer] The request's length in bytes.
      # @param reply [String] The reply buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none, or the size needed negated.
      def call(context, topic, request, length, reply, size)
        @functions['mp_call'].call(context, topic, request, length, reply, size)
      end

      # Hands out a parked reply (mp_reply).
      #
      # @param context [Integer] The context from the handshake.
      # @param reply [String] The reply buffer, now large enough.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The reply's length, 0 for none.
      def reply(context, reply, size)
        @functions['mp_reply'].call(context, reply, size)
      end

      # Takes the queued events (mp_drain).
      #
      # @param context [Integer] The context from the handshake.
      # @param frame [Integer] The bridge's frame.
      # @param buffer [String] The drain buffer.
      # @param size [Integer] Its size in bytes.
      # @return [Integer] The events' length, 0 for none, or the size needed negated.
      def drain(context, frame, buffer, size)
        @functions['mp_drain'].call(context, frame, buffer, size)
      end
    end

    # The battle server's way to its core library (MGQOnline.ServerCore) through Fiddle, with the
    # same four functions, called as Win32Backend calls them. The game never makes one: RGSS3 has
    # no Fiddle.
    class FiddleBackend < Win32Backend
      # Fiddle's type for each letter of SIGNATURES.
      TYPES = { 'l' => :TYPE_INT, 'p' => :TYPE_VOIDP }

      # Loads the library and binds the four functions without calling one, since the core's
      # runtime starts at the first call.
      #
      # @param path [String] The core library's path.
      # @raise [Fiddle::DLError] The library cannot be loaded or lacks one of the functions.
      def initialize(path)
        require 'fiddle'
        # Kept, so the library stays loaded while the functions live.
        @library = Fiddle.dlopen(path)
        @functions = {}
        SIGNATURES.each do |name, arguments|
          types = arguments.chars.map { |letter| Fiddle.const_get(TYPES[letter]) }
          @functions[name] = Fiddle::Function.new(@library[name], types, Fiddle::TYPE_INT)
        end
      end
    end

    # Opens the bridge to the DLL.
    #
    # @param path [String] The DLL's path, relative to the game's folder.
    # @return [Boolean] Whether it opened; the log tells why not.
    def self.start(path)
      backend =
        begin
          Win32Backend.new(path)
        rescue => e
          return refuse("#{path} lacks the bridge's exports (#{e.class}: #{e.message}), so it is older than these scripts")
        end
      open(backend)
    end

    # Shakes hands with C# through a backend. Until one succeeds, every call answers nil and a
    # frame does nothing.
    #
    # @param backend [#open, #call, #reply, #drain] The four exports, see Win32Backend.
    # @return [Boolean] Whether the bridge opened; the log tells why not.
    def self.open(backend)
      close
      @backend = backend
      @reply = buffer(REPLY_SIZE)
      length = backend.open(VERSION, @reply, @reply.bytesize)
      if length < 0
        # The DLL parked its answer, which the next handshake hands out.
        @reply = buffer(-length)
        length = backend.open(VERSION, @reply, @reply.bytesize)
      end
      return refuse("the DLL answered no handshake, as a stand-in DLL does") if length <= 0

      answer = Marshal.load(@reply[0, length])
      return refuse("the DLL refused the handshake: #{answer['text']}") unless answer["ok"]

      value = answer["value"]
      return refuse("the DLL speaks bridge version #{value['bridge']}, these scripts #{VERSION}") if value["bridge"] != VERSION

      @topics = value["topics"]
      @events = buffer(DRAIN_SIZE)
      @frame = 0
      @context = value["context"]
      Log.write("bridge: opened context #{@context} with the DLL of build #{value['build']}, #{@topics.size} topic(s)")
      true
    rescue => e
      refuse("the handshake failed: #{e.class}: #{e.message}")
    end

    # Closes the bridge and forgets what was staged and which failures were logged; the handlers
    # stay.
    def self.close
      @context = nil
      @staged = []
      @failures = {}
    end

    # Tells whether the handshake succeeded.
    #
    # @return [Boolean] Whether the bridge is open.
    def self.open?
      !@context.nil?
    end

    # Tells whether the DLL answers a topic.
    #
    # @param topic [String] The topic.
    # @return [Boolean] Whether the handshake named it.
    def self.has?(topic)
      open? && @topics.include?(topic)
    end

    # Calls a topic and takes its value. An error it answers is logged once per topic and code.
    #
    # @param topic [String] The topic, such as "story.mapping".
    # @param request [Object] A plain value, nil for none.
    # @return [Object, nil] The topic's value; nil for none, for an error and while the bridge is
    #   closed.
    def self.call(topic, request = nil)
      answer = exchange(topic, request)
      return nil if answer.nil?
      return answer["value"] if answer["ok"]

      failed(topic, answer["error"], answer["text"])
      nil
    rescue => e
      failed(topic, "script", "#{e.class}: #{e.message}")
      nil
    end

    # Calls a topic, for a caller that must know whether it answered.
    #
    # @param topic [String] The topic.
    # @param request [Object] A plain value, nil for none.
    # @return [Object, nil] The topic's value, nil for none.
    # @raise [Error] The topic answered an error, or the bridge is closed.
    def self.call!(topic, request = nil)
      raise Error, "the bridge is closed, so #{topic} was not called" unless open?

      answer = exchange(topic, request)
      return nil if answer.nil?
      return answer["value"] if answer["ok"]

      raise Error, "#{topic} answered #{answer['error']}: #{answer['text']}"
    end

    # Stages what a script hands over during a frame, which the next frame sends in one batch with
    # the rest, in order. Nothing is staged while the bridge is closed.
    #
    # @param topic [String] The topic, such as "story.write".
    # @param payload [Object] A plain value.
    def self.stage(topic, payload = nil)
      @staged << [topic, payload] if @context
      nil
    end

    # Registers a handler for a topic's events, which a frame's drain hands to every handler of
    # the topic in order.
    #
    # @param topic [String] The topic, such as "story.push".
    # @yieldparam payload [Object] The event's plain value.
    def self.on(topic, &handler)
      ((@handlers ||= {})[topic] ||= []) << handler
    end

    # Sends what was staged and takes the DLL's events, once a frame after Graphics.update.
    #
    # The bridge counts its own frames, which never go back as Graphics.frame_count does when a
    # save loads, since C#'s timers run on them.
    def self.frame
      return unless @context

      @frame = @frame >= MAX_FRAME ? 0 : @frame + 1
      send_staged
      drain
    end

    # Tells the bridge's frame, the one the last drain passed, which C#'s timers count by.
    #
    # @return [Integer] The frame, 0 before the first.
    def self.frame_number
      @frame.to_i
    end

    # Sends what was staged at once, outside the frame, such as the log's last lines as the game
    # closes.
    def self.flush
      send_staged if @context
    end

    # Sends the staged entries as one batch and logs each entry that failed, once per topic and
    # code.
    def self.send_staged
      return if @staged.empty?

      failures = call(BATCH, @staged)
      @staged.clear
      failures.each { |entry| failed(entry["topic"], entry["error"], entry["text"]) } if failures.is_a?(Array)
    end

    # Takes the DLL's events and hands each to its topic's handlers.
    def self.drain
      length = @backend.drain(@context, @frame, @events, @events.bytesize)
      if length < 0
        # The DLL parked the events, which the next drain of the frame hands out.
        @events = buffer(-length)
        length = @backend.drain(@context, @frame, @events, @events.bytesize)
      end
      return if length <= 0

      Marshal.load(@events[0, length]).each { |topic, payload| dispatch(topic, payload) }
    rescue => e
      failed("(drain)", "script", "#{e.class}: #{e.message}")
    end

    # Hands an event to its topic's handlers; one that fails is logged and the others still run.
    #
    # @param topic [String] The event's topic.
    # @param payload [Object] The event's plain value.
    def self.dispatch(topic, payload)
      handlers = @handlers && @handlers[topic]
      return failed(topic, "no_handler", "no script takes its events") unless handlers

      handlers.each do |handler|
        begin
          handler.call(payload)
        rescue => e
          failed(topic, "handler", "#{e.class}: #{e.message}")
        end
      end
    end

    # Calls a topic through the backend: the request dumped, a parked reply taken into a grown
    # buffer, and the reply loaded at once, since the next call writes into the same buffer.
    #
    # @param topic [String] The topic.
    # @param request [Object] A plain value, nil for none.
    # @return [Hash, nil] The reply's envelope, nil for no reply or while the bridge is closed.
    def self.exchange(topic, request)
      return nil unless @context

      dump = request.nil? ? NO_REQUEST : Marshal.dump(request)
      length = @backend.call(@context, name_of(topic), dump, dump.bytesize, @reply, @reply.bytesize)
      if length < 0
        @reply = buffer(-length)
        length = @backend.reply(@context, @reply, @reply.bytesize)
      end
      length > 0 ? Marshal.load(@reply[0, length]) : nil
    end

    # Names a topic as the DLL reads it, made once per topic.
    #
    # @param topic [String] The topic.
    # @return [String] The topic, null-terminated.
    def self.name_of(topic)
      (@names ||= {})[topic] ||= "#{topic}\0"
    end

    # Makes a buffer the DLL writes into.
    #
    # @param size [Integer] Its size in bytes.
    # @return [String] The buffer, binary, so its length counts bytes.
    def self.buffer(size)
      ("\0" * size).force_encoding("ASCII-8BIT")
    end

    # Logs a failure, once per topic and code.
    #
    # @param topic [String] The topic.
    # @param code [String] The error code, such as "bad_request", or what failed in the scripts.
    # @param text [String] What went wrong.
    def self.failed(topic, code, text)
      key = "#{topic} #{code}"
      return if @failures[key]

      @failures[key] = true
      Log.write("bridge: #{topic} failed with #{code}: #{text}")
    end

    # Keeps the bridge closed and logs why, which turns the mod off.
    #
    # @param reason [String] Why it did not open.
    # @return [Boolean] false.
    def self.refuse(reason)
      close
      Log.write("bridge: the mod stays off, #{reason}")
      false
    end
  end

  # Asks the relay for the release to play, or GitHub for the latest release, once per game session,
  # on a thread of the DLL's own, see MGQ_Multiplayer.outdated?.
  module UpdateCheck
    # Frames between two looks at the DLL, half a second at 60 frames per second.
    CHECK_FRAMES = 30

    # Starts the check on the DLL's own thread, once per game session. A development build never
    # asks.
    def self.start
      return if @started
      @started = true
      return unless MGQ_Multiplayer.available?

      Link.function('mp_check_for_update').call
      Log.write("asked the DLL for the release to play; its answer follows in its own lines")
    end

    # Polls the DLL for the release to install. Called every frame, acts every CHECK_FRAMES, and
    # stops asking once one was found.
    def self.tick
      return if @version

      @frames = (@frames || 0) + 1
      return if @frames < CHECK_FRAMES

      @frames = 0
      text = Link.read('mp_newer_version', 64)
      return if text.empty?

      @version = text
      @rollback = Link.function('mp_update_rollback').call == 1
      Log.write("update gate closed: release #{text} is #{@rollback ? 'the one to play, a step back' : 'out'}, so worlds and PvP battles stay shut until it is installed")
    rescue => e
      Log.write("update check failed: #{e.class}: #{e.message}")
    end

    # Reads the version of the release to install, once the check found one other than the
    # installed one.
    #
    # @return [String, nil] The version, nil while none was found.
    def self.version
      @version
    end

    # Tells whether the release to install is older than the installed one.
    #
    # @return [Boolean] Whether it is, false while none was found.
    def self.rollback?
      @rollback == true
    end
  end

  # Keeps the game running while another window is in front, which RGSS pauses it for otherwise, so
  # neither player holds the other up, and ignores the buttons meanwhile.
  module Background
    # The Input methods that report buttons, with what each reports while none is pressed.
    IDLE_INPUT = { :press? => false, :trigger? => false, :repeat? => false, :dir4 => 0, :dir8 => 0 }

    # Has the DLL keep the game running.
    def self.start
      @running = Link.keep_running
      Log.write(@running ? "hooked the game's window: it keeps running in the background and the keyboard types" : "could not keep the game running in the background")
    rescue => e
      Log.write("background start failed: #{e.class}: #{e.message}")
    end

    # Reports whether the DLL hooked the game's window, which keeps the game running and passes on
    # what the player types.
    #
    # @return [Boolean] Whether the window is hooked.
    def self.running?
      @running == true
    end

    # Has Input report no buttons while another window is in front or while a screen of the mod
    # holds them (Capture), through core_hooks.rbx.
    #
    # The keyboard only reaches the window in front, but gamepads reach every game, so a pad played
    # in another game would play this one too.
    def self.guard_input
      return if @input_guarded

      input = Input.singleton_class
      MGQ_MpHooks.before(input, :update, "Multiplayer") do
        MGQ_Multiplayer::Background.refresh
        MGQ_Multiplayer::Capture.next_frame
        MGQ_Multiplayer::Key.read_watched
      end
      IDLE_INPUT.each do |method, idle|
        MGQ_MpHooks.around(input, method, "background") { |_input, _args, original| MGQ_Multiplayer::Background.passes? ? original.call : idle }
      end
      @input_guarded = true
      Log.write("guarded the game's Input")
    end

    # Reports whether Input answers as the game's own would: while the game is in front, no screen
    # of the mod gave the buttons back in this frame, and none holds them unless it asks past the
    # capture.
    #
    # @return [Boolean] Whether it does.
    def self.passes?
      in_front? && !Capture.released? && (!Capture.on? || Capture.reading?)
    end

    # Asks Windows whether the window in front belongs to this game, once per frame.
    #
    # Input.update calls it, since the game's Graphics.frame_count raises until the game first sets it.
    def self.refresh
      in_front = begin
        Windows.game_in_front?
      rescue
        true
      end
      Log.write(in_front ? "the game's window came to the front" : "another window came to the front, the buttons wait") if !@in_front.nil? && in_front != @in_front
      @in_front = in_front
    end

    # Reports whether the window in front belongs to this game, as Windows said at the last
    # Input.update.
    #
    # @return [Boolean] true before the input is guarded or while Windows cannot tell.
    def self.in_front?
      @in_front != false
    end
  end

  # Takes the buttons away from the game while a screen of the mod reads them, such as a menu drawn
  # over the map, under which the player would walk or open the game's menu otherwise.
  module Capture
    # The screens that hold the buttons, each until it gives them back, so one screen closing never
    # hands the buttons to the game under another.
    @owners = []

    # Takes the buttons for a screen.
    #
    # @param owner [Symbol] The screen, such as :wheel.
    def self.start(owner)
      return if @owners.include?(owner)

      @owners.push(owner)
      Log.write("buttons taken by #{owner}, held by #{@owners.join(', ')}")
    end

    # Gives the buttons back for a screen. The game gets them once no other screen holds them, from
    # the next frame on.
    #
    # @param owner [Symbol] The screen.
    def self.stop(owner)
      return unless @owners.delete(owner)

      @released = true if @owners.empty?
      Log.write("buttons given back by #{owner}, #{@owners.empty? ? 'the game has them again from the next frame' : "still held by #{@owners.join(', ')}"}")
    end

    # Reports whether the last screen gave the buttons back in this frame.
    #
    # The press that closed the screen, such as the Escape that closed the chat box, still reads
    # as pressed until the next Input.update, where a battle's wait would take it as leaving.
    #
    # @return [Boolean] Whether it did.
    def self.released?
      @released == true
    end

    # Starts a frame, in which buttons given back in the frame before reach the game again. Called
    # before every Input.update.
    def self.next_frame
      @released = false
    end

    # Reports whether a screen holds the buttons.
    #
    # @return [Boolean] Whether one does.
    def self.on?
      !@owners.empty?
    end

    # Reports whether a screen of the mod asks Input past the capture right now.
    #
    # @return [Boolean] Whether one does.
    def self.reading?
      @reading == true
    end

    # Reports whether a button went down, past the capture, while the game window is in front.
    #
    # @param button [Symbol] The game's button, such as :C or :UP.
    # @return [Boolean] Whether it went down.
    def self.trigger?(button)
      read(:trigger?, button)
    end

    # Reports whether a button is held, past the capture, while the game window is in front.
    #
    # @param button [Symbol] The game's button, such as :UP.
    # @return [Boolean] Whether it is held.
    def self.press?(button)
      read(:press?, button)
    end

    # Reports whether a button went down or repeats while held, past the capture, while the game
    # window is in front.
    #
    # @param button [Symbol] The game's button, such as :LEFT.
    # @return [Boolean] Whether it went down or repeats.
    def self.repeat?(button)
      read(:repeat?, button)
    end

    # Asks Input about a button past the capture, while the game window is in front.
    #
    # @param method [Symbol] :press?, :trigger? or :repeat?.
    # @param button [Symbol] The game's button.
    # @return [Boolean] What Input answers.
    def self.read(method, button)
      return false unless Background.in_front?

      @reading = true
      Input.send(method, button)
    ensure
      @reading = false
    end
  end

  # Keys the game's own Input does not know, read from Windows.
  module Key
    # Set in a key state while the key is down.
    DOWN = 0x8000

    # Frames counted by next_frame.
    @frame = 0

    # The keys told frame by frame, see triggered?: each code with whether it was down at the last
    # Input.update and whether it went down then.
    @watched = {}

    # Counts a frame for pressed?. Called after every Graphics.update, which runs once a frame,
    # unlike Input.update.
    def self.next_frame
      @frame += 1
    end

    # Tells the frames counted by next_frame, which run on the title screen too, where the game's
    # Graphics.frame_count raises.
    #
    # @return [Integer] The frames.
    def self.frame
      @frame
    end

    # Reads the watched keys. Called before every Input.update.
    def self.read_watched
      @watched.each do |code, state|
        down = raw_down?(code)
        state[:went_down] = down && !state[:down]
        state[:down] = down
      end
    end

    # Reads keys at every Input.update from now on, so triggered? can tell their presses.
    #
    # @param codes [Array<Integer>] Windows' codes of the keys.
    def self.watch(*codes)
      codes.each { |code| @watched[code] ||= { :down => false, :went_down => false } }
    end

    # Reports whether a key went down at the last Input.update, while the game window is in front,
    # as Input.trigger? tells the game's buttons: the same answer however often it is asked in that
    # frame.
    #
    # The game's windows call Input.update again as they cancel, which ends the press, so a key that
    # is also a button of the game never cancels twice.
    #
    # @param code [Integer] Windows' code of the key, watched from its first ask on.
    # @return [Boolean] Whether the key went down.
    def self.triggered?(code)
      watch(code)
      @watched[code][:went_down] && Background.in_front?
    end

    # Reports whether a key went down since the last call for it, while the game window is in front.
    #
    # Windows reports the key whichever window has the focus, so a press in another window is
    # ignored.
    #
    # @param code [Integer] Windows' code of the key, such as 0x7A for F11.
    # @return [Boolean] Whether the key went down.
    def self.pressed?(code)
      @down ||= {}
      @asked ||= {}
      down = raw_down?(code)
      # A key asked about only while a screen is open may have been let go while none was.
      pressed = down && !(@down[code] && @asked[code] >= @frame - 1)
      @down[code] = down
      @asked[code] = @frame
      pressed && Background.in_front?
    end

    # Reports whether a key is held, while the game window is in front, without taking its press
    # from pressed?.
    #
    # @param code [Integer] Windows' code of the key, such as 0x12 for Alt.
    # @return [Boolean] Whether the key is down.
    def self.down?(code)
      raw_down?(code) && Background.in_front?
    end

    # Asks Windows whether a key is down, whichever window is in front.
    #
    # @param code [Integer] Windows' code of the key.
    # @return [Boolean] Whether it is down.
    def self.raw_down?(code)
      (Windows.api('user32', 'GetAsyncKeyState', 'i', 'i').call(code) & DOWN) != 0
    end
    private_class_method :raw_down?
  end

  # The mouse over the game's window, read from Windows: where it points on the game's screen, and
  # its left button.
  module Mouse
    # Windows' code of the left mouse button.
    LEFT_BUTTON = 0x01

    # Tells where the mouse points on the game's screen, while the game window is in front.
    #
    # The window may be larger than the game's screen, which RGSS stretches over it.
    #
    # @return [Array<Integer>, nil] x and y in the game's pixels, nil outside the window or while
    #   another window is in front.
    def self.position
      return nil unless Background.in_front?

      window = Windows.api('user32', 'GetForegroundWindow', 'v', 'l').call
      point = [0, 0].pack('l2')
      return nil if Windows.api('user32', 'GetCursorPos', 'p', 'i').call(point) == 0

      Windows.api('user32', 'ScreenToClient', 'lp', 'i').call(window, point)
      rect = [0, 0, 0, 0].pack('l4')
      Windows.api('user32', 'GetClientRect', 'lp', 'i').call(window, rect)
      x, y = point.unpack('l2')
      width, height = rect.unpack('l4')[2, 2]
      return nil if width <= 0 || height <= 0 || x < 0 || y < 0 || x >= width || y >= height

      [x * Graphics.width / width, y * Graphics.height / height]
    rescue
      nil
    end

    # Reports whether the left button went down since the last call, while the game window is in
    # front and the player does not arrange the mod's boxes.
    #
    # @return [Boolean] Whether it went down.
    def self.clicked?
      # Asked even while arranging, so a press held over the end of it is not taken as a new one.
      pressed = Key.pressed?(LEFT_BUTTON)
      pressed && !arranging?
    end

    # Reports whether the left button is held, while the game window is in front and the player does
    # not arrange the mod's boxes.
    #
    # @return [Boolean] Whether it is.
    def self.held?
      Key.down?(LEFT_BUTTON) && !arranging?
    end

    # The DLL's export that hands out the wheel's notches.
    WHEEL_EXPORT = 'mp_mouse_wheel'

    # Tells how many notches the wheel turned since the last frame, read once a frame of
    # Key.frame, so every box that asks in a frame gets the same; 0 while another window is in
    # front, while the player arranges the mod's boxes, or without the export.
    #
    # Notches gathered while nobody asked in the frame before are dropped, so a box that opens
    # never scrolls by an earlier turn.
    #
    # @return [Integer] The notches, positive up, away from the player, negative down.
    def self.wheel
      frame = Key.frame
      unless frame == @wheel_frame
        notches = take_wheel
        notches = 0 unless @wheel_frame == frame - 1
        @wheel_frame = frame
        @wheel = notches
      end
      Background.in_front? && !arranging? ? @wheel : 0
    rescue
      0
    end

    # Takes the notches the DLL gathered since it was last asked, telling the log once when it
    # cannot.
    #
    # @return [Integer] The notches, 0 without the export.
    def self.take_wheel
      return 0 if @wheel_missing

      Link.function(WHEEL_EXPORT).call
    rescue => e
      @wheel_missing = true
      Log.write("mouse wheel unavailable: #{e.class}: #{e.message}")
      0
    end
    private_class_method :take_wheel

    # Tells whether the mouse moves and resizes the mod's boxes instead of clicking, see
    # ui_layout.rbx.
    #
    # @return [Boolean] Whether it does.
    def self.arranging?
      defined?(MGQ_MpUi::Layout) && MGQ_MpUi::Layout.arranging? ? true : false
    end
  end

  # The Windows functions the script calls directly.
  module Windows
    # Asks Windows whether the game is in front.
    #
    # @return [Boolean] Whether the window in front belongs to this game.
    def self.game_in_front?
      owner = [0].pack('L')
      api('user32', 'GetWindowThreadProcessId', 'lp', 'l').call(api('user32', 'GetForegroundWindow', 'v', 'l').call, owner)
      owner.unpack('L')[0] == api('kernel32', 'GetCurrentProcessId', 'v', 'l').call
    end

    # Loads a Windows function.
    #
    # @param library [String] The Windows library.
    # @param name [String] The function.
    # @param arguments [String] Its arguments, in Win32API notation.
    # @param result [String] Its result, in Win32API notation.
    # @return [Win32API] The function, loaded once.
    def self.api(library, name, arguments, result)
      @functions ||= {}
      @functions[name] ||= Win32API.new(library, name, arguments, result)
    end
  end

  # Hands the connection to the Discord mod through MGQ_Discord::Bridge when it is installed, and
  # takes the invites the player accepted and the player's name from it. Everything here does
  # nothing without it, and the join code on the clipboard still works.
  module Discord
    # The bridge version this script speaks, see MGQ_Discord::Bridge.
    BRIDGE_VERSION = 1

    # Tells whether the Discord mod can take the connection.
    #
    # @return [Boolean] Whether the Discord mod is installed and speaks this script's bridge version.
    def self.available?
      defined?(MGQ_Discord::Bridge) && MGQ_Discord::Bridge::VERSION == BRIDGE_VERSION && MGQ_Discord::Bridge.available? ? true : false
    end

    # Hands the connection to the Discord mod when it changed, and takes an invite the player
    # accepted in Discord: into a world, or to a PvP battle. Called every frame, acts every
    # DISCORD_FRAMES.
    def self.tick
      @frames = (@frames || 0) + 1
      return if @frames < DISCORD_FRAMES

      @frames = 0
      return unless MGQ_Multiplayer.available? && bridge_found?

      invite = MGQ_Discord::Bridge.take_invite
      if invite
        world = defined?(MGQ_MpWorld) && MGQ_MpWorld::Invite.receive(invite)
        Link.receive_invite(invite) unless world
        Log.write(world ? "took a Discord invite into a world" : "took a Discord invite to a PvP battle")
      end
      report(Link.status)
    rescue => e
      Log.write("discord hand-over failed: #{e.class}: #{e.message}")
    end

    # Tells whether the Discord mod can take the connection, logging when that changes.
    #
    # @return [Boolean] Whether it can, see available?.
    def self.bridge_found?
      found = available?
      status = bridge_status(found)
      Log.write(status) if status != @bridge_status
      @bridge_status = status
      found
    end

    # Describes how the Discord mod stands, for the log.
    #
    # @param found [Boolean] Whether it can take the connection.
    # @return [String] The description.
    def self.bridge_status(found)
      return "Discord mod found, bridge version #{BRIDGE_VERSION}" if found
      return "Discord mod not installed, the join code on the clipboard still works" unless defined?(MGQ_Discord::Bridge)

      version = MGQ_Discord::Bridge::VERSION rescue nil
      return "Discord mod speaks bridge version #{version.inspect}, this mod #{BRIDGE_VERSION}: not used" if version != BRIDGE_VERSION

      "Discord mod installed but not connected to Discord yet"
    rescue
      "Discord mod could not be asked"
    end

    # Tells the DLL the player's name, which the friend sees: the one on Discord, or the one the
    # player chose for Multiplayer.
    def self.share_player_name
      name = Player.name
      Link.set_player_name(name) if name
    rescue => e
      Log.write("player name failed: #{e.class}: #{e.message}")
    end

    # Reads the player's name on Discord.
    #
    # @return [String, nil] The name, nil without the Discord mod or until Discord told it.
    def self.player_name
      available? ? MGQ_Discord::Bridge.player_name : nil
    rescue
      nil
    end

    # Hands the connection to the Discord mod, unless it did not change since the last time.
    #
    # @param state [Hash] How the connection stands, see Link.status.
    def self.report(state)
      party = state["party"]
      current =
        if party && state["state"] == "hosting" && state["code"]
          [:hosting, party, state["code"]]
        elsif party && state["link"] == "open"
          [:connected, party, MGQ_Multiplayer.clean(state["opponent"])]
        else
          [:idle]
        end
      return if current == @reported

      @reported = current
      kind, party, detail = current
      Log.write(kind == :idle ? "told Discord: idle" : "told Discord: #{kind}, party #{party.to_s[0, 8]}#{kind == :connected ? " with #{detail}" : ''}")
      case kind
      when :hosting then MGQ_Discord::Bridge.hosting(party, detail)
      when :connected then MGQ_Discord::Bridge.connected(party, detail)
      else MGQ_Discord::Bridge.idle
      end
    end
  end
end

# The Russian translation's own loader catches no error a mod raises, so this file catches its own,
# which would otherwise end the game.
begin
  MGQ_Multiplayer.start
  MGQ_Multiplayer.load_scripts
  # The last resort for a game whose Main section lets Ruby end: the log writes how it closes and
  # every line left. The game's own Main section never gets here, see MGQ_Multiplayer.run_game.
  at_exit { MGQ_Multiplayer.closing($!) }
rescue Exception => e
  MGQ_Multiplayer.load_failed("loading", e)
end

# Game hooks, through core_hooks.rbx.

begin
  # After every frame, counts it for the keys, sends what the scripts staged for the bridge and
  # takes its events, tells the Discord mod how the connection stands, polls for an update and logs
  # the hooks registered since the last frame. Graphics.update runs every frame in every scene, so
  # all happen wherever the player is.
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "Multiplayer") do
    MGQ_Multiplayer::Key.next_frame
    MGQ_Multiplayer::Bridge.frame
    MGQ_Multiplayer::Discord.tick
    MGQ_Multiplayer::UpdateCheck.tick
    MGQ_MpHooks.report
  end

  # Guards the input as the game starts running. The game's plugins load after the Patch folder,
  # the gamepad one wrapping Input, so the guard wraps Input once every plugin is in.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "Multiplayer") do
    MGQ_Multiplayer.note_run
    MGQ_Multiplayer::Background.guard_input
  end

  # The scenes ending, as a quit, the window closing or an error ends them, write how the game
  # closes and every line left while the game still runs, before its error box or its end.
  MGQ_MpHooks.around(SceneManager.singleton_class, :run, "Multiplayer") { |_manager, _args, original| MGQ_Multiplayer.run_game(original) }
rescue Exception => e
  MGQ_Multiplayer.load_failed("hooks", e)
end
