#----------------------------------------------------------------
#  Multiplayer.rb
#
#  Changelog:
#      Paulinchen  2026-10-09: Loaded world_catchup_data.rbx before world_story.rbx, the generated data of a Raid World's catch-up
#                            - Loaded world_catchup.rbx after world_story.rbx, which carries a player behind a Raid World's story along by their level
#      Paulinchen  2026-10-08: Loaded coop_scope.rbx after coop.rbx, which tells the party scripts whom the player shares the map and the story with
#                            - Loaded world_story.rbx after coop_story.rbx and world.rbx, a Raid World's story at the relay, and named the mp_raid_* exports it calls
#                            - Loaded battles_raid_bosses.rbx before battles_coop.rbx, and battles_coop_hotjoin.rbx after it, whose hook wraps the live battle's
#                            - Named mp_dir_create with the world's type and how a Raid World shares companions
#                            - Told whether a key or the left mouse button is held, for the chat log's tabs and its size
#                            - Took a key nobody asked about in the frame before as let go, so the numpad's 0 that closed a screen closes the next one too
#                            - Named mp_update_game, which starts the mod's updater, and told the player to pick Multiplayer to update
#                            - Told a watched key's press frame by frame, ended by the Input.update of a game window's cancel
#                            - Counted the frames for Key.pressed? at Graphics.update, since a game window's cancel calls Input.update twice in a frame, which made a held key read as a new press
#                            - Counted the sessions kept by the scripts' logs alone, keeping a DLL's log named a moment before its session's
#                            - Deleted no logs in a game started for the options dump, whose log no longer counts as a session
#                            - Counted only the old logs actually deleted, and logged those that could not be
#      Paulinchen  2026-10-07: Named mp_world_say, which mirrors a chat line to the relay for the world's admins
#                            - Kept the logs of the last five game sessions, deleting older ones as a session starts
#                            - Logged the hooks as one line per script with its count, once the scripts loaded and once a frame
#                            - Logged how the game closes and each F12 reset, so a log that just stops tells a crash
#                            - Kept the press that closes a screen of the mod from reaching the game in the same frame, which left a PvP battle when Escape closed the chat box
#                            - Gave the background wrap its script, as every around now names who registers
#                            - Named every export of the DLL with its signature once in Link, so a call names the export alone
#                            - Loaded coop_choices.rbx, the story's choices a member makes for themselves, after the world screen whose form it draws with
#                            - Wrote the in-game log without a line or size limit into a file per game session, named after the time the game started
#                            - Logged the start, the scripts loaded, the Discord mod found, the update gate, the buttons taken and given back, the player's name and the PvP link's steps
#                            - Forgot the chosen name when the player clears it, so the name on Discord stands again instead of A friend
#      Paulinchen  2026-10-06: Kept the buttons held while any screen of the mod holds them, so one closing never hands them to the game under another
#                            - Guarded Input through core_hooks.rbx, asking Windows every frame whether the game is in front, also where the game pauses in the background
#                            - Kept up to 3000 lines of the in-game log per session instead of 60, which ended it within minutes, counted a repeated line instead of writing it again, saying so while it repeats and when the game closes, and moved a log grown past 1 MB aside as the old log when a session starts
#                            - Loaded coop_story_rewards.rbx before coop_story.rbx
#                            - Handed a Discord invite into a world to world.rbx instead of the PvP connection
#                            - Kept the last name Discord told, which stands in while Discord has not told one yet, as right after a restart
#                            - Wrote the in-game log as Multiplayer InGame.log into the game folder's Logs folder
#                            - Loaded trade.rbx and ui_trade.rbx after battles_team.rbx
#                            - Told whether a button is held past the capture, for the wheels' arrows
#                            - Loaded ui_wheel.rbx before ui_actions.rbx
#                            - Loaded world_mods.rbx after world.rbx
#      Paulinchen  2026-10-04: Loaded battles_coop_level_sync.rbx after battles_coop.rbx
#                            - Loaded ui_party_box.rbx after world_overview.rbx
#                            - Loaded ui_emotes.rbx after ui_chat.rbx
#                            - Loaded coop_scene.rbx after coop_gather.rbx
#                            - Loaded coop_gather.rbx and coop_castle.rbx, split out of coop_events.rbx
#                            - Loaded the scripts by their new names, which say what each belongs to instead of mp_
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
#                            - Added Mouse, where the mouse points on the game's screen and its left button
#      Paulinchen  2026-09-30: Loaded the other scripts from Patch/Multiplayer/Scripts
#                            - Loaded ui_chat.rbx after the action wheel
#                            - Loaded coop.rbx before the party scripts that register with it
#                            - Loaded overworld_sync.rbx before the scripts that register with it
#                            - Moved the mod folder into Patch/Multiplayer and loaded the other scripts from there in a fixed order
#                            - Called the battle and party scripts by their new names
#                            - Named the mod Monster Girl Quest! Online in the update message
#                            - Asked GitHub for a newer release and told MGQ_MpWorld and MGQ_MpBattlesPvp to disable themselves once one is out
#                            - Read held buttons past the capture too, which moves a text cursor
#      Paulinchen  2026-09-29: Said in $mgq_text_input while the player types, so other mods' hotkeys stay quiet
#                            - Added Capture, which takes the buttons away from the game while a screen of the mod reads them
#                            - Told whether the game's window is hooked, which the keyboard needs
#                            - Told the DLL the player's key and name for worlds, and read typing from the keyboard through it
#                            - Added Player, the player's id and name, which PvP battles pass on when Discord knows no name
#                            - Found the mod folder relative to the game's folder, which works in a folder named with characters outside ASCII
#                            - Hosted without a port, since games meet at the relay
#                            - Added Link.status, which leaves the friend's team out, for the frequent checks
#      Paulinchen  2026-09-28: Created
#
#----------------------------------------------------------------

# What every way of playing together shares: the connection with a friend through
# Patch/Multiplayer/Multiplayer.dll, the game running on while its window is in the background,
# keys the game's own Input does not know, and the Discord mod, when it is installed. It also loads
# the mod's other scripts, see SCRIPTS.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_Multiplayer
  # Turns the mod off without uninstalling it.
  ENABLED = true

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
  # coop.rbx, which the scripts after them register with. The battle scripts install their battle hooks once the game runs, the last
  # loaded first, so their order decides how those hooks wrap each other.
  SCRIPTS = %w[
    core_log core_hooks core_game_access core_hotkeys ui ui_text_box core_actors core_async overworld_sync ui_wheel ui_actions ui_chat ui_emotes overworld
    coop coop_scope coop_squad coop_events coop_gather coop_scene coop_npcs coop_story_rewards coop_story coop_castle
    world world_mods world_catchup_data world_story world_catchup world_save_distribution world_text world_screen world_save_export coop_choices
    battles battles_raid_bosses battles_coop battles_coop_hotjoin battles_coop_level_sync
    battles_sync battles_sync_wire battles_sync_recorder battles_sync_playback battles_sync_live
    battles_balance_pvp battles_pvp battles_pvp_backline battles_pvp_mirror battles_pvp_lobby battles_duel battles_team
    trade ui_trade
    world_overview ui_party_box ui_notices
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

  # Tells whether the mod can run.
  #
  # @return [Boolean] Whether the mod is on and its DLL is in the mod folder.
  def self.available?
    ENABLED && File.exist?(path(DLL))
  end

  # Starts the DLL and keeps the game running in the background, once per game session.
  def self.start
    return if @started
    @started = true
    Log.write("Monster Girl Quest! Online starting on Ruby #{RUBY_VERSION}, session log #{Log.file_name}")
    Log.prune
    unless available?
      Log.write(ENABLED ? "not started: #{path(DLL)} is missing" : "not started: the mod is turned off")
      return
    end

    Link.start
    Log.write("started #{path(DLL)}")
    Background.start
    UpdateCheck.start
  rescue => e
    Log.write("start failed: #{e.class}: #{e.message}")
  end

  # Tells whether a newer release of the mod is out, which MGQ_MpWorld and MGQ_MpBattlesPvp disable
  # themselves for, so two games speaking a protocol a refactor changed never meet.
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

  # The newer release's version, once the check found one.
  #
  # @return [String, nil] The version, nil until one was found.
  def self.newer_version
    UpdateCheck.version
  end

  # Builds the path of a file inside the mod folder, relative to the game's folder.
  #
  # The game always runs in its own folder. An absolute path breaks in a folder named with
  # characters outside ASCII, such as the untranslated game's: File takes it only as UTF-8,
  # Win32API loads a DLL only from the system's code page. A relative one, with backslashes, works
  # for both.
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

  # The scripts' log in the game folder's Logs folder, one file per game session, such as
  # Logs/Multiplayer InGame 2026-10-07 18-30-05.log, named after the time the game started, as the
  # DLL names its Multiplayer.log of the same session.
  module Log
    # The start of the log's file name, which the session's start and ".log" follow.
    NAME = "Multiplayer InGame"

    # How the session's start shows in the file name.
    STAMP = "%Y-%m-%d %H-%M-%S"

    # How often a line repeats before the log says so while it still repeats, so a flood shows even
    # when the game closes first.
    REPEAT_REPORTS = [10, 100, 1000, 10_000]

    # Game sessions whose logs the Logs folder keeps, this one among them; the older ones go as a
    # session starts.
    KEPT_SESSIONS = 5

    # A session's log of this mod, the scripts', the DLL's or an options dump's, and the session's
    # start in its name.
    SESSION_LOG = /\AMultiplayer(?: InGame)? (\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2})(?: options dump)?\.log\z/

    # The scripts' log of a game session the player played, which alone counts the sessions kept.
    PLAYED_LOG = /\AMultiplayer InGame (\d{4}-\d{2}-\d{2} \d{2}-\d{2}-\d{2})\.log\z/

    # Seconds the DLL may name its log of a session before the scripts' log of it.
    #
    # Each names its log after the game's start as Windows tells it, but when Windows cannot tell,
    # as under Wine, after its own start, which differs by the moments between them.
    SESSION_SLACK = 60

    # What ends the name of the scripts' log of a game the World Admin tool started for the options
    # dump, which quits at once and so is no session the player played.
    DUMP_SUFFIX = " options dump"

    # The environment variable through which the World Admin tool asks for the options dump, as
    # world_mods.rbx's MGQ_MpWorldMods::DUMP_SETTING names it.
    DUMP_SETTING = "MGQMP_OPTIONS_DUMP"

    # When this script loaded, which stands in for the game's start when Windows cannot tell it.
    @loaded = Time.now
    @last = nil
    @streak = 0
    @reported = 0

    # Appends a line, prefixed with the time. A line the same as the one before is only counted;
    # the count is written once the streak ends, and at REPEAT_REPORTS while it goes on.
    #
    # @param message [String] The line to append.
    def self.write(message)
      if message == @last
        @streak += 1
        append("(the line above repeated #{@streak} times so far)") if REPEAT_REPORTS.include?(@streak)
        @reported = @streak if REPEAT_REPORTS.include?(@streak)
        return
      end

      flush
      @last = message
      append(message)
    rescue
    end

    # Writes how often the last line repeated, unless the log said so already. Called when another
    # line comes and when the game closes.
    def self.flush
      append("(the line above repeated #{@streak} times in all)") if @streak > @reported
      @streak = 0
      @reported = 0
    rescue
    end

    # Appends one line, prefixed with the time.
    #
    # @param text [String] The line.
    def self.append(text)
      File.open(MGQ_Multiplayer.log_path(file_name), "ab") { |file| file.write("#{Time.now}  #{text}\n") }
    end

    # Deletes the logs of every session older than the newest KEPT_SESSIONS the player played, the
    # scripts', the DLL's and those of options dumps, since each game start writes a pair and nothing
    # else ever removes them. A game started for the options dump deletes nothing.
    def self.prune
      return if dump_run? || !File.directory?(LOG_DIR)

      logs = Dir.entries(LOG_DIR).select { |name| name =~ SESSION_LOG }
      played = (logs.map { |name| name[PLAYED_LOG, 1] }.compact | [session_stamp]).sort.reverse
      return if played.size <= KEPT_SESSIONS

      oldest_kept = time_of(played[KEPT_SESSIONS - 1]) - SESSION_SLACK
      gone = logs.select { |name| time_of(name[SESSION_LOG, 1]) < oldest_kept }
      deleted = gone.count { |name| (File.delete("#{LOG_DIR}\\#{name}") rescue 0) == 1 }
      write("deleted #{deleted} log(s) of sessions older than the last #{KEPT_SESSIONS}") if deleted > 0
      write("could not delete #{gone.size - deleted} old log(s)") if deleted < gone.size
    rescue => e
      write("deleting old logs failed: #{e.class}: #{e.message}")
    end

    # Tells whether the World Admin tool started the game for the options dump, see
    # MGQ_MpWorldMods.dump_requested?.
    #
    # @return [Boolean] Whether it did.
    def self.dump_run?
      !ENV[DUMP_SETTING].to_s.empty?
    rescue
      false
    end

    # Reads the time a log's name shows.
    #
    # @param stamp [String] Such as "2026-10-07 18-30-05".
    # @return [Time] The time, in local time.
    def self.time_of(stamp)
      Time.local(*stamp.scan(/\d+/).map { |part| part.to_i })
    end

    # Names this session's log after the game's start, read once.
    #
    # @return [String] The file name, such as "Multiplayer InGame 2026-10-07 18-30-05.log", with
    #   DUMP_SUFFIX before ".log" for a game started for the options dump.
    def self.file_name
      @file_name ||= "#{NAME} #{session_stamp}#{dump_run? ? DUMP_SUFFIX : ''}.log"
    end

    # Writes when the game started, in local time, as the log's name shows it.
    #
    # @return [String] The time, such as "2026-10-07 18-30-05".
    def self.session_stamp
      (process_start || @loaded).strftime(STAMP)
    end

    # Asks Windows when the game's process started.
    #
    # @return [Time, nil] The start in local time, to the second; nil when Windows cannot tell.
    def self.process_start
      times = Array.new(4) { [0, 0].pack("L2") }
      process = Windows.api("kernel32", "GetCurrentProcess", "v", "l").call
      return nil if Windows.api("kernel32", "GetProcessTimes", "lpppp", "i").call(process, *times) == 0

      local = [0, 0].pack("L2")
      system = ([0] * 8).pack("S8")
      return nil if Windows.api("kernel32", "FileTimeToLocalFileTime", "pp", "i").call(times[0], local) == 0
      return nil if Windows.api("kernel32", "FileTimeToSystemTime", "pp", "i").call(local, system) == 0

      year, month, _weekday, day, hour, minute, second = system.unpack("S8")
      Time.local(year, month, day, hour, minute, second)
    rescue
      nil
    end
  end

  # Files of key=value lines, such as Patch/Multiplayer/Player.ini.
  module Ini
    # Reads a file.
    #
    # @param path [String] The file.
    # @return [Hash] The values by key, empty when the file is missing or unreadable.
    def self.read(path)
      values = {}
      return values unless File.exist?(path)

      File.open(path, "rb") { |file| file.read }.force_encoding("UTF-8").split(/\r?\n/).each do |line|
        key, value = line.split("=", 2)
        values[key.strip] = value.strip if value
      end
      values
    rescue => e
      Log.write("could not read #{path}: #{e.class}: #{e.message}")
      {}
    end

    # Writes a file, replacing it.
    #
    # @param path [String] The file.
    # @param values [Hash] The values by key, each kept on its line.
    # @return [Boolean] Whether the file was written.
    def self.write(path, values)
      lines = values.map { |key, value| "#{key}=#{value.to_s.gsub(/[\r\n]/, ' ')}\n" }
      File.open(path, "wb") { |file| file.write(lines.join) }
      true
    rescue => e
      Log.write("could not write #{path}: #{e.class}: #{e.message}")
      false
    end
  end

  # Who plays this game: an id that tells it from every other player's, kept in
  # Patch/Multiplayer/Player.ini, and the name the others see.
  module Player
    # File that keeps the id and the chosen name, inside the mod folder.
    FILE = "Player.ini"

    # Setting that keeps the last name Discord told.
    DISCORD_NAME = "discord_name"

    # Reads the player's id, making one the first time.
    #
    # @return [String] The id, "" when none could be made.
    def self.id
      values = load
      if values["id"].to_s.empty?
        values["id"] = Link.new_id
        Ini.write(MGQ_Multiplayer.path(FILE), values) unless values["id"].empty?
        Log.write(values["id"].empty? ? "could not make a player key: the DLL gave none" : "made a new player key and kept it in #{FILE}")
      end
      values["id"].to_s
    end

    # Reads the name the others see: the one the player chose for Multiplayer, or else their name on
    # Discord, or the last one Discord told while it has not told one yet.
    #
    # @return [String, nil] The name, nil while the player chose none and Discord never told one.
    def self.name
      chosen = load["name"].to_s
      return MGQ_Multiplayer.clean(chosen) unless chosen.empty?

      discord = Discord.player_name.to_s
      if discord.empty?
        discord = load[DISCORD_NAME].to_s
      elsif load[DISCORD_NAME] != discord
        store(DISCORD_NAME, discord)
        Log.write("kept the name Discord told: #{discord}")
      end
      discord.empty? ? nil : MGQ_Multiplayer.clean(discord)
    end

    # Keeps the name the player chose, which replaces their name on Discord; an empty one forgets
    # the chosen name, so the name on Discord stands again.
    #
    # @param name [String] The name.
    def self.name=(name)
      chosen = MGQ_Multiplayer.clean(name, "")
      chosen.empty? ? forget("name") : store("name", chosen)
      Log.write(chosen.empty? ? "cleared the chosen name, the name on Discord stands: #{self.name.inspect}" : "chose the name #{chosen}")
      share
    end

    # Reads a setting of Player.ini, such as a key the player bound.
    #
    # @param key [String] The setting.
    # @return [String, nil] Its value, nil while it is not set.
    def self.setting(key)
      load[key]
    end

    # Keeps a setting in Player.ini.
    #
    # @param key [String] The setting.
    # @param value [Object] Its value.
    # @return [Boolean] Whether Player.ini was written.
    def self.store(key, value)
      values = load
      values[key] = value.to_s
      Ini.write(MGQ_Multiplayer.path(FILE), values)
    end

    # Removes a setting from Player.ini.
    #
    # @param key [String] The setting.
    # @return [Boolean] Whether Player.ini was written.
    def self.forget(key)
      values = load
      values.delete(key)
      Ini.write(MGQ_Multiplayer.path(FILE), values)
    end

    # Tells the DLL who plays, once the player has a name.
    #
    # @return [Boolean] Whether the DLL knows who plays.
    def self.share
      name = self.name
      key = id
      shared = name && !key.empty? ? Link.set_player(key, name) : false
      told = [name, shared]
      if told != @told
        @told = told
        Log.write(shared ? "told the DLL who plays: #{name}" : "could not tell the DLL who plays: #{name.nil? ? 'no name yet' : key.empty? ? 'no player key' : 'it refused'}")
      end
      shared
    rescue => e
      Log.write("could not tell the DLL who plays: #{e.class}: #{e.message}")
      false
    end

    # Reads Player.ini once.
    #
    # @return [Hash] The values by key.
    def self.load
      @values ||= Ini.read(MGQ_Multiplayer.path(FILE))
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

    # Every export of the DLL with its arguments in Win32API notation, 'v' for none; each returns a
    # long. A call names the export alone, so a changed signature is followed here once.
    EXPORTS = {
      # The DLL itself, the player and the update check.
      'mp_start' => 'v',
      'mp_keep_running' => 'v',
      'mp_check_for_update' => 'v',
      'mp_newer_version' => READ_ARGUMENTS,
      'mp_new_id' => READ_ARGUMENTS,
      'mp_set_player' => 'pp',
      'mp_set_player_name' => 'p',
      'mp_player_id' => READ_ARGUMENTS,
      'mp_restart_game' => 'v',
      'mp_update_game' => 'v',

      # The keyboard and the clipboard.
      'mp_typing' => 'l',
      'mp_take_typed' => READ_ARGUMENTS,
      'mp_copy_code' => 'v',
      'mp_copy_text' => 'p',

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
      'mp_dir_find' => 'p',
      'mp_dir_list' => READ_ARGUMENTS,
      'mp_dir_create' => 'pplllpppplpppp',
      'mp_dir_unlock' => 'pp',
      'mp_dir_unlock_code' => 'p',
      'mp_dir_edit' => 'plpppl',
      'mp_dir_set_settings' => 'pp',
      'mp_dir_set_data' => 'pp',
      'mp_dir_delete' => 'p',
      'mp_dir_ban' => 'pp',
      'mp_dir_action' => READ_ARGUMENTS,
      'mp_dir_clear' => 'v',
      'mp_dir_fetch_start' => 'pp',

      # The world's room.
      'mp_world_id' => 'ppl',
      'mp_world_directory_id' => 'ppl',
      'mp_world_open' => 'p',
      'mp_world_close' => 'v',
      'mp_world_send' => 'lp',
      'mp_world_say' => 'p',
      'mp_world_receive' => READ_ARGUMENTS,
      'mp_world_status' => READ_ARGUMENTS,

      # The mod catalog.
      'mp_mods_list' => READ_ARGUMENTS,
      'mp_mod_hash' => 'ppl',
      'mp_mods_install' => 'p',
      'mp_mods_options' => 'ppp',

      # Trades.
      'mp_trade_commit' => 'pppp',
      'mp_trade_cancel' => 'pp',
      'mp_trade_state' => READ_ARGUMENTS,
      'mp_trade_done' => 'pp',
      'mp_trade_pending' => 'p',
      'mp_trade_pending_list' => READ_ARGUMENTS,

      # A Raid World's story at the relay.
      'mp_raid_story_fetch' => 'p',
      'mp_raid_story_post' => 'plpp',
      'mp_raid_story_state' => READ_ARGUMENTS,
      'mp_raid_story_headers' => READ_ARGUMENTS,
      'mp_raid_checkpoint_fetch' => 'pp',
      'mp_raid_checkpoint_state' => READ_ARGUMENTS,
      'mp_raid_route_lock' => 'pp',
      'mp_raid_companions_add' => 'pp',
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

    # Makes an id nobody else has.
    #
    # @return [String] 32 lowercase hexadecimal characters, "" when it failed.
    def self.new_id
      read('mp_new_id', 64)
    end

    # Tells the DLL who plays in worlds.
    #
    # @param key [String] The player's key.
    # @param name [String] The player's name.
    # @return [Boolean] Whether the DLL took them.
    def self.set_player(key, name)
      function('mp_set_player').call(key + "\0", name + "\0") == 1
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

    # Takes what the player typed since the last call.
    #
    # @return [Array] The typed characters, Enter, Backspace and Escape among them as "\r", "\b"
    #   and "\e"; and how many keys went down.
    def self.take_typed
      text = read('mp_take_typed', 1024)
      return ["", 0] if text.empty?

      state = parse(text)
      [state[:payload], state["keys"].to_i]
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

    # Calls an export that writes a text into a buffer, again with a larger buffer when asked for one.
    #
    # @param name [String] The export, one that takes READ_ARGUMENTS.
    # @param size [Integer] The buffer's size at first.
    # @return [String] The text as bytes, "" when there is none.
    def self.read(name, size)
      buffer = "\0" * size
      length = function(name).call(buffer, buffer.size)

      if length < 0
        buffer = "\0" * (1 - length)
        length = function(name).call(buffer, buffer.size)
      end

      # The DLL wrote bytes past Ruby's back, so only a binary string counts them right.
      length > 0 ? buffer.force_encoding("ASCII-8BIT")[0, length] : ""
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

  # Asks GitHub for the latest release of the mod, once per game session, on a thread of the DLL's
  # own, so two games speaking a protocol a refactor changed never meet.
  module UpdateCheck
    # Frames between two looks at the DLL, half a second at 60 frames per second.
    CHECK_FRAMES = 30

    # Starts the check on the DLL's own thread, once per game session. A development build never asks.
    def self.start
      return if @started
      @started = true
      return unless MGQ_Multiplayer.available?

      Link.function('mp_check_for_update').call
      Log.write("asked the DLL to look for a newer release; Multiplayer.log tells its answer")
    end

    # Polls the DLL for a newer release. Called every frame, acts every CHECK_FRAMES, and stops
    # asking once one was found.
    def self.tick
      return if @version

      @frames = (@frames || 0) + 1
      return if @frames < CHECK_FRAMES

      @frames = 0
      text = Link.read('mp_newer_version', 64)
      return if text.empty?

      @version = text
      Log.write("update gate closed: release #{text} is out, so worlds and PvP battles stay shut until the update")
    rescue => e
      Log.write("update check failed: #{e.class}: #{e.message}")
    end

    # The latest release's version, once the check found it newer than the installed one.
    #
    # @return [String, nil] The version, nil while none was found.
    def self.version
      @version
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

    # Reports whether the window in front belongs to this game, as Windows said at the last Input.update.
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
    # as pressed until the next Input.update, and a battle's wait took it as leaving the battle.
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

    @frame = 0

    # The keys told frame by frame, see triggered?: each code with whether it was down at the last
    # Input.update and whether it went down then.
    @watched = {}

    # Counts a frame for pressed?. Called after every Graphics.update, which runs once a frame,
    # unlike Input.update.
    def self.next_frame
      @frame += 1
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
    # frame. The game's windows call Input.update again as they cancel, which ends the press, so a
    # key that is also a button of the game never cancels twice.
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

    # Reports whether the left button went down since the last call, while the game window is in front.
    #
    # @return [Boolean] Whether it went down.
    def self.clicked?
      Key.pressed?(LEFT_BUTTON)
    end

    # Reports whether the left button is held, while the game window is in front.
    #
    # @return [Boolean] Whether it is.
    def self.held?
      Key.down?(LEFT_BUTTON)
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

  # The Discord mod, when it is installed: it shows the connection on the player's profile, offers
  # the invites, and hands over the ones the player accepted and the player's name. Everything here
  # does nothing without it, and the join code on the clipboard still works.
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
    # accepted in Discord: into a world, or to a PvP battle. Called every frame, acts every DISCORD_FRAMES.
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

MGQ_Multiplayer.start
MGQ_Multiplayer.load_scripts
# When the game closes, the log writes how often its last line repeated, then how the game closes.
at_exit do
  MGQ_Multiplayer::Log.flush
  MGQ_Multiplayer::Log.write(MGQ_Multiplayer.closing_text($!))
end

# Game hooks, through core_hooks.rbx.

begin
  # After every frame, counts it for the keys, tells the Discord mod how the connection stands, polls for an update and
  # logs the hooks registered since the last frame. Graphics.update runs every frame in every
  # scene, so all happen wherever the player is.
  MGQ_MpHooks.after(Graphics.singleton_class, :update, "Multiplayer") do
    MGQ_Multiplayer::Key.next_frame
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
rescue => e
  MGQ_Multiplayer::Log.write("hooks FAILED: #{e.class}: #{e.message}")
end
