#----------------------------------------------------------------
#  world_mods.rbx
#
#  Changelog:
#      Paulinchen  2026-10-30: Locked the options a world sets through the Mod Framework's options, Mod Config Remake's without it
#                            - Entered a world that turns other mods off with only the mods its session keeps, and started again for one that turns them off now
#                            - Entered a world's game only right before its save loads or its New Game starts, and handed the DLL the options of the mods that loaded
#                            - Installed a world's mods through the Mod Framework, and entered the world again after its restart
#                            - Joined the open world's messages once every script loaded
#      Paulinchen  2026-10-23: Dropped the creator's hashes, the settings' marker, the settings an edit starts from and those the relay took, which the DLL's requests read themselves
#                            - Left the download of a world's mods and the summary of its check to the DLL's steps into a world
#                            - Left the restart for downloaded mods and the world to enter again to the DLL's parking
#                            - Forgot the installed scripts and the world's settings through topics of their own names, and dropped list_text, which the DLL's texts replace
#                            - Left the shared mod settings' rules, their sending, the relay's check and the notices to the DLL, playing its steps
#                            - Left the required-mods check, the creator's hashes, the download, the options an admin sends and the battle server's mods to the DLL
#                            - Took the mod catalog from the DLL as plain values instead of parsing its text
#                            - Started the game again for downloaded mods under Wine or Proton too
#                            - Deleted the options dump for the World Admin tool, its setting and its check
#      Paulinchen  2026-10-22: Took a world's settings only once the list carries its mods, and as many settings and mod hashes as the relay's new limit
#                            - Said the version to play for a step back when the entry after a restart is refused
#      Paulinchen  2026-10-15: Listed the world's mods and their options this game runs for the battle server
#      Paulinchen  2026-10-13: Left the mod's single player group out of the options dump
#      Paulinchen  2026-10-12: Listed the Shared Mod Settings row among the mod's settings and left the mod's groups out of the options dump
#      Paulinchen  2026-10-09: Read the catalog's personal mods
#                            - Took the open world's mods from the relay
#                            - Waited with entering a world again while the title screen restarts the game for the parked mods, and put them back instead of offering the update
#      Paulinchen  2026-10-08: Let the creator share their mod settings or not through a Mod Config row every player sees
#                            - Sent the creator's options of the world's mods as its settings whenever they change while it shares them
#                            - Told every player in the world the new settings at once, and a player whose game holds others as they tell their state
#                            - Told the players what a world that shares its settings sets for them
#                            - Left out a value the player's copy of an option does not offer, and set and locked nothing in a world that shares none
#                            - Wrote every mod's Mod Config options into a file for the World Admin tool when started for it
#                            - Opened the options dump's file by its name alone in the game's folder, or in UTF-8
#                            - Kept the settings the relay took last over a list from before them, and checked a player anew who takes a seat someone left
#                            - Said when settings could not be sent or got no answer, and kept every notice within three lines
#                            - Named the stay's settings anew instead of a change when they arrive right after the load
#                            - Counted and named only the options this game's Mod Config has, and said when a world shares none yet
#                            - Applied only settings of options a world may set in a mod's group of this game's Mod Config
#                            - Kept the world to enter when the game cannot start itself again under Wine or Proton
#                            - Offered the update on the title screen to an outdated game started again to enter a world
#                            - Took only the directory's answer to its own settings, resent them when another request took its place, and forgot them with the world
#                            - Read the world's settings on the relay before sending the creator's or telling a player whose game holds others
#                            - Added the row of Shared Mod Settings to a Mod Config without entries too, and rescued noting the world entered
#                            - Told the creator when the relay holds settings someone else set
#      Paulinchen  2026-10-07: Sent the Mod Config options of every installed catalog mod, whatever its version
#                            - Logged a catalog unknown at the first read too
#                            - Followed a new game through an after block
#                            - Named the DLL's exports alone
#                            - Logged the mod checks, the catalog read, the downloads, the restart and rejoin, and the settings
#      Paulinchen  2026-10-06: Said a world needs mods that are missing or in another version
#                            - Asked a scene directly whether it changes
#                            - Kept the catalog while the list is fetched again
#                            - Left catalog mods the relay could not read yet out of the catalog
#                            - Sent the Mod Config options once a session
#                            - Read an option's values from its :values too
#                            - Kept the world's settings within the 2000 characters the relay takes, and told the creator what was left out
#                            - Left mod names longer than the relay takes out of the creator's hashes
#                            - Sent the Mod Config options of each catalog mod this admin's game has in the catalog's version
#                            - Added a Mod Config button for the world's creator to set the world's mod settings, and left the creator's options unlocked
#                            - Took the world's mod settings from every mod it names
#                            - Read decimal settings with a plus sign in their exponent
#                            - Applied the world's mod settings from load_game_without_rescue
#                            - Checked a link to a zip of a release file by file
#                            - Created
#
#----------------------------------------------------------------

# A world's mods: the ones its creator marked as required, which every game that enters must have
# in the same version, and the creator's settings of every mod it names, which hold while the
# player is in the world. A game whose copy of a catalog mod is missing or differs may install it
# through the Mod Framework and enter the world, the mod loading as the player enters; a required
# mod outside the catalog is checked against the hash of the creator's copy.
# A world that turns other mods off loads only the mods it names and the personal ones as the
# player enters it, through the Mod Framework's session. A world shares its creator's Mod Config
# Remake options as its settings, or leaves every player
# their own. An admin's game sends every catalog mod's options, and a game the World Admin tool
# starts writes them into a file and quits.
#
# Mod Config Remake keeps the options in each save, and a world has saves of its own, so the
# player's own saves keep their own settings.
module MGQ_MpWorldMods
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "world mods"

  # The topic that hands out the relay's mod catalog.
  CATALOG_TOPIC = "mods.catalog"

  # Seconds between two readings of the catalog.
  CATALOG_SECONDS = 1.0

  # The topic that checks a world's required mods.
  CHECK_TOPIC = "mods.check"

  # The topic that forgets the scripts in Patch and their hashes.
  FORGET_INSTALLED_TOPIC = "mods.forget"

  # The topic that lists the mods of a world the battle server runs.
  SERVED_TOPIC = "mods.served"

  # The topic that names the catalog mods whose options an admin's game sends now.
  REPORT_TOPIC = "mods.report"

  # The topic that sends a mod's Mod Config options.
  OPTIONS_TOPIC = "mods.options"

  # The row of Mod Config that tells whether the world shares its creator's settings.
  SHARED_OPTION = :mgq_mp_shared_mod_settings

  # The row's name, in the group of the mod's settings.
  ROW_NAME = "#{MGQ_MpUi::OPTION_PREFIX}Shared Mod Settings"

  # What the row says while On.
  ROW_ON_HELP = "Every player here plays with the creator's mod options."

  # What the row says while Off.
  ROW_OFF_HELP = "Each player here sets their own mod options."

  # The marker's key, as settings_from reads it.
  MARKER_KEY = :"@shared"

  # The field that marks the creator's message of the world's new settings.
  LIVE_FIELD = "world_mods"

  # The field of a player's state that holds the checksum of the settings their game applies.
  STATE_FIELD = "mod_settings"

  # An option's name that opens its mod's group, "[Mod Name] Option", as Mod Config Remake reads it.
  MOD_NAME = /\A\s*\[([^\]]+)\]\s*/

  # An option's name that joins the group above: indented, or behind an arrow.
  INDENTED = /\A(\s|->)/

  # What the world screen says when no Mod Framework installs mods.
  NO_FRAMEWORK_TEXT = "Mods cannot be installed without the Mod Framework. Install MGQ Online again."

  # The topic that names the mods of a world's session.
  SESSION_TOPIC = "mods.session"

  # The topic that names the mods of the session the open world turns off now.
  NOW_OFF_TOPIC = "mods.now_off"

  # The key of the notice of the mods a world leaves out.
  OFF_NOTICE_KEY = :world_mods_off

  # Frames a player in a world that now turns their mods off is told so before the game starts
  # again, once the map is free, five seconds.
  KICK_FRAMES = 300

  # The key of this script's lines in the notification box.
  NOTICE_KEY = :world_mod_settings

  # Frames a notice shows, ten seconds.
  NOTICE_FRAMES = 600

  # Most lines a notice takes, as many as the DLL breaks it into.
  NOTICE_LINES = 3

  # The topic that notes the world being entered.
  ENTER_TOPIC = "settings.enter"

  # The topic that forgets the world and the settings on their way.
  FORGET_WORLD_TOPIC = "settings.forget"

  # The topic that takes this game's Mod Config groups for the notices.
  GROUPS_TOPIC = "settings.options"

  # The topic that notes a save of the world loaded or started.
  LOADED_TOPIC = "settings.loaded"

  # The topic that makes the creator's options the world's settings.
  WANT_TOPIC = "settings.want"

  # The topic that hands out the steps waiting for this script.
  STEP_TOPIC = "settings.step"

  # The topic that takes the options set for the creator's live settings.
  APPLIED_TOPIC = "settings.applied"

  # The topic that takes the settings the creator sent live.
  LIVE_TOPIC = "settings.live"

  # The topic that takes another player's state.
  OBSERVE_TOPIC = "settings.observe"

  # The topic that notes another player was told the world's settings.
  TOLD_TOPIC = "settings.told"

  # The topic that forgets what a player who left was told.
  LEAVE_TOPIC = "settings.leave"

  # The topic that takes the mods the open world names now.
  MODS_TOPIC = "settings.mods"

  # The topic that tells whether settings are shared.
  SHARED_TOPIC = "settings.shared"

  # The topic that says what the details say about a world's settings.
  DETAILS_TOPIC = "settings.details"

  # A required mod this game lacks or has in another version, as the DLL checks it (ModCheck in
  # MGQOnline.Game).
  #
  # @!attribute name [String] The mod's name, as the world writes it.
  # @!attribute yours [String] This game's version: "not installed", the version, "unknown" or "differs".
  # @!attribute worlds [String, nil] The world's version, nil when only the creator's hash tells it.
  # @!attribute key [String, nil] The catalog mod's key, which can be downloaded; nil for a mod outside the catalog.
  # @!attribute target [String, nil] Where a link mod's script goes, relative to the game's folder.
  # @!attribute text [String] The difference for the player, such as "Level Cap: yours 1.0.0, the world's 1.1.0".
  Row = Struct.new(:name, :yours, :worlds, :key, :target, :text) do
    # Tells whether the world's version can be downloaded.
    #
    # @return [Boolean] Whether it can.
    def downloadable?
      !key.nil?
    end
  end

  # Takes part in the open world's messages: the creator's settings sent live, each player's state,
  # which tells the settings their game applies, and the relay's word on the world's mods rule.
  def self.join_world
    return unless defined?(MGQ_MpOverworldSync)

    MGQ_MpOverworldSync.route(LIVE_FIELD) { |peer, message| MGQ_MpWorldMods.take_live(peer, message) }
    MGQ_MpOverworldSync.on_observe { |peer| MGQ_MpWorldMods.on_observe(peer) }
    MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpWorldMods.on_leave(peer) }
    MGQ_MpOverworldSync.state_fields { MGQ_MpWorldMods.state_fields }
    MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::MODS_RULE_FIELD) { |_peer, message| MGQ_MpWorldMods.rule_pushed(message) } if defined?(MGQ_MpOverworldSync::MODS_RULE_FIELD)
  end

  # Reads which mods the relay's catalog marks personal, at most once a second.
  #
  # @return [Array<String>, nil] The keys of the personal mods and of their names, as
  #   MGQ_MpWorld.mod_key makes them; nil while the catalog is unknown.
  def self.personal_keys
    return @personal if @catalog_read && Time.now - @catalog_read < CATALOG_SECONDS

    @catalog_read = Time.now
    told = MGQ_Multiplayer::Bridge.call(CATALOG_TOPIC)
    state = told ? told["state"] : "failed"
    # The DLL hands out the catalog it had while it fetches the list again.
    return @personal if state == "loading" && told["mods"].empty? && told["personal"].empty?

    @personal = %w(ready loading).include?(state) ? told["personal"] : nil
  end

  # Forgets what was read of the installed mods, as the world screen opens or after an install.
  def self.forget_installed
    @catalog_read = nil
    MGQ_Multiplayer::Bridge.call(FORGET_INSTALLED_TOPIC)
    MGQ_MpWorld.forget_installed
  end

  # Lists the required mods of a world that this game lacks or has in another version, as the DLL
  # checks them against the catalog, this game's copies and the creator's hashes.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Array<Row>] The mods, none when every one matches or the DLL did not answer.
  def self.differing(listed)
    checked = MGQ_Multiplayer::Bridge.call(CHECK_TOPIC, "mods" => listed.mods.to_s, "hashes" => listed.mod_hashes.to_s, "world" => nil)
    return [] unless checked.is_a?(Hash)

    checked["rows"].map { |row| Row.new(row["name"], row["yours"], row["worlds"], row["key"], row["target"], row["text"]) }
  end

  # Takes the world the game should enter again after a restart, once, which the DLL's parking
  # keeps, the one way back into a world after a restart.
  #
  # @return [String, nil] The world's id, nil when there is none.
  def self.take_rejoin
    world = @restarted_for
    @restarted_for = nil
    world
  end

  # Notes the mods of the session of the world the world screen enters, which enter_game loads: a
  # world that turns other mods off keeps only some of them.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld, nil] The world as the list has it, nil when
  #   the list lacks it.
  def self.note_session(listed)
    @entering = nil
    return unless defined?(MGQ_Multiplayer::Stages) && MGQ_Multiplayer::Stages.staged?

    session = listed && listed.other_mods_off ? session_of(listed) : nil
    @entering = { :name => listed ? listed.name.to_s : "a world", :session => session }
  rescue => e
    log("noting the mods of the world's session failed: #{e.class}: #{e.message}")
  end

  # Enters the game through the Mod Framework for the world noted, right before its save loads or
  # its New Game starts: the mods of its session load, the player is told which stay off and which
  # stay on, and the DLL takes the options of the mods that loaded. Earlier, any way back to the
  # title, such as the one to the world's New Game, would start the game again. The mods that run
  # from the start of the game are noted first, since once entered every mod counts as running until
  # the game starts again (rule_pushed).
  def self.enter_game
    entering = @entering
    @entering = nil
    return unless entering

    @from_start = Mod_Framework::Mods.stays_on if defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:stays_on)
    session = entering[:session]
    entered = MGQ_Multiplayer::Stages.enter("the world #{entering[:name]}", session && session["only"])
    MGQ_MpNotices.message(OFF_NOTICE_KEY, session["text"], KICK_FRAMES) if session && session["text"] && defined?(MGQ_MpNotices)
    hand_options(true) if entered
  rescue => e
    log("entering the game for a world failed: #{e.class}: #{e.message}")
  end

  # Names the mods of a world's session, which turns other mods off.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Hash, nil] "only", "off" and "text", see the DLL's mods.session; nil while unknown,
  #   when every mod that is on loads.
  def self.session_of(listed)
    mods = Mod_Framework::Mods
    names = Array((mods.plan || {})["load"]).map { |name, _tag| name }
    session = MGQ_Multiplayer::Bridge.call(SESSION_TOPIC, "world" => listed.name.to_s, "mods" => listed.mods.to_s, "names" => names, "stays_on" => mods.stays_on)
    log(session.is_a?(Hash) ? "#{listed.name} turns other mods off: its session keeps #{session['only'].join(', ')}" : "#{listed.name} turns other mods off, but the catalog is unknown: every mod that is on loads")
    session.is_a?(Hash) ? session : nil
  end

  # Takes the relay's word that the open world's creator or an admin changed whether it turns other
  # mods off, or its mods: a game whose session runs mods it turns off now is told so and starts
  # again into the world, without them.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::MODS_RULE_FIELD with "1" or "0", the
  #   world's mods under "mods", marked :relay by overworld_sync.rbx.
  def self.rule_pushed(message)
    return log("ignored a mods rule push not from the relay") unless message[:relay]

    mods = message["mods"].to_s
    take_mods(mods)
    world = MGQ_MpWorld.world
    return unless world && defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:stays_on)

    running = Mod_Framework::Mods.loaded - Array(@from_start)
    told = MGQ_Multiplayer::Bridge.call(NOW_OFF_TOPIC, "world" => world.name.to_s, "off" => message[MGQ_MpOverworldSync::MODS_RULE_FIELD].to_s == "1", "mods" => mods, "running" => running)
    return unless told.is_a?(Hash) && told["text"]

    log("#{world.name} now turns off #{told['off'].join(', ')}, which this session runs")
    @kick = { :text => told["text"], :frames => KICK_FRAMES, :told => false, :world => world.directory_id, :name => world.name.to_s }
  rescue => e
    log("taking the relay's mods rule failed: #{e.class}: #{e.message}")
  end

  # Tells a player in a world that now turns their mods off, then starts the game again into the
  # world once the map is free. Called every frame of every scene.
  def self.follow_kick
    return unless @kick
    return @kick = nil unless MGQ_MpWorld.open?

    unless @kick[:told]
      @kick[:told] = true
      MGQ_MpNotices.message(OFF_NOTICE_KEY, @kick[:text], KICK_FRAMES) if defined?(MGQ_MpNotices)
    end
    @kick[:frames] -= 1
    return if @kick[:frames] > 0 || !MGQ_MpOverworldSync.map_free?

    kick = @kick
    @kick = nil
    restart_for(kick[:world], kick[:name])
  end

  # Notes the world the Mod Framework started the game again to enter, whose title opens the world
  # screen on it (MGQ_Multiplayer::Stages::REJOIN_ACTION).
  #
  # @param world [String] The world's id.
  def self.restarted_for(world)
    @restarted_for = world.to_s
    log("the game started again to enter world #{MGQ_MpWorld.short(@restarted_for)}")
  end

  # Installs a world's mods through the Mod Framework, while the game goes on.
  #
  # @param rows [Array<Array(String, String)>] Each mod's name, as the world writes it, and its key
  #   in the relay's catalog.
  # @yield [ok, text, restart] Runs once the install ended, or at once when it could not start.
  # @yieldparam ok [Boolean] Whether every mod was installed.
  # @yieldparam text [String, nil] Why not, for the player.
  # @yieldparam restart [Boolean] Whether a mod installed runs already, which loads anew only after
  #   the game starts again.
  def self.install(rows, &done)
    return done.call(false, NO_FRAMEWORK_TEXT, false) unless defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:install)

    ids = rows.map { |name, key| framework_id(name, key) }
    log("installing #{rows.map { |name, _key| name }.join(', ')} through the Mod Framework as #{ids.join(', ')}")
    Mod_Framework::Mods.install(ids) do |installed, error|
      running = error ? [] : installed.select { |name| Mod_Framework::Mods.loaded.any? { |loaded| loaded.casecmp(name) == 0 } }
      log(error ? "installing the world's mods failed: #{error}" : "installed #{installed.join(', ')}#{running.empty? ? '' : ", of which #{running.join(', ')} runs already"}")
      done.call(error.nil?, error, !running.empty?)
    end
  end

  # Names a world's mod as the Mod Framework installs it: the id of the installed mod of that key,
  # else of the website's or the relay's mod the framework finds for its name, else the relay's.
  #
  # @param name [String] The mod's name, as the world writes it.
  # @param key [String] Its key in the relay's catalog.
  # @return [String] The id, such as "relay:levelcap".
  def self.framework_id(name, key)
    state = Mod_Framework::Mods.state
    mods = state.is_a?(Hash) ? Array(state["mods"]) : []
    installed = mods.find { |mod| mod["id"] && [mod["name"], mod["title"]].any? { |each| MGQ_MpWorld.mod_key(each) == key } }
    return installed["id"] if installed

    found = Array(Mod_Framework::Mods.check([[name, "", ""]])).find { |row| row["kind"] == "install" && !row["target"].to_s.empty? }
    found ? found["target"] : "relay:#{key}"
  end

  # Starts the game again to enter a world, once a mod installed for it runs already, which the
  # Mod Framework loads anew only in a new game session.
  #
  # @param world [String] The world's id.
  # @param name [String] Its name, for the log.
  # @return [Symbol, nil] :restarting or :closing, see Mod_Framework::Mods.restart; nil without the
  #   framework.
  def self.restart_for(world, name)
    return nil unless defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:restart)

    log("starting the game again to enter #{name} with its mods loaded anew")
    Mod_Framework::Mods.restart("#{name} needs a mod that runs already loaded anew", MGQ_Multiplayer::Stages::REJOIN_ACTION, world)
  end

  # Forgets a world the player backed out of before its new game, and opens the world screen to
  # enter a world again after a restart, or offers the update once a newer release is out. Called
  # by the title screen every frame.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    forget_world if @world && !MGQ_MpWorld.open?
    return if @rejoining || scene.scene_changing?

    id = take_rejoin
    return unless id
    return log("not entering world #{MGQ_MpWorld.short(id)} again after the restart: the DLL is missing") unless MGQ_Multiplayer.available?

    if MGQ_Multiplayer.outdated?
      log("not entering world #{MGQ_MpWorld.short(id)} again after the restart: the mod is outdated")
      return MGQ_MpWorld.offer_update(scene)
    end

    @rejoining = id
    log("entering world #{MGQ_MpWorld.short(id)} again after the restart")
    SceneManager.call(Scene_MpWorlds)
  rescue => e
    log("entering the world again failed: #{e.class}: #{e.message}")
  end

  # Takes the world the world screen should enter on its own, once it is in the list.
  #
  # @return [String, nil] The world's id.
  def self.rejoining
    @rejoining
  end

  # Forgets the world to enter on its own, once the world screen entered it or gave up.
  def self.rejoined
    @rejoining = nil
  end

  # Mod Config's options.

  # Lists Mod Config Remake's groups as it sorts them: an entry named "[Name] ..." opens group
  # Name, an indented one joins the group above, any other one is Global and left out. A name met
  # again adds to its group.
  #
  # @return [Array<Array(String, Array<Hash>)>] Each group's name and entries, in the order the
  #   groups first appear.
  def self.menu_groups
    return [] unless defined?(NWConst::Config::MOD_CONTENTS)

    groups = []
    current = nil
    NWConst::Config::MOD_CONTENTS.each do |entry|
      name = name_of(entry)
      if name =~ MOD_NAME
        current = $1
      elsif name !~ INDENTED
        current = nil
      end
      next unless current

      group = groups.find { |known, _| known == current } || (groups << [current, []]).last
      group[1] << entry
    end
    groups
  end

  # Reads an entry's name, which a mod may give as a proc.
  #
  # @param entry [Hash] The entry in MOD_CONTENTS.
  # @return [String] The name, "" when it fails.
  def self.name_of(entry)
    name = entry[:name]
    (name.respond_to?(:call) ? name.call : name).to_s
  rescue
    ""
  end

  # Names an option as its row shows it, without "[Mod Name]" and the arrow of an indented one.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [String] Such as "Job and Race Limits".
  def self.short_name(entry)
    name_of(entry).sub(MOD_NAME, "").sub(/\A[\s\->]+/, "").strip
  end

  # Lists the options of some mods that a world may set: those with values, not key bindings,
  # and not marked personal.
  #
  # @param keys [Array<String>] The mods' keys.
  # @return [Array<Symbol>] The options' keys.
  def self.world_options(keys)
    world_entries(keys).map { |entry| entry[:key] }
  end

  # Finds the Mod Config entries of some mods that a world may set.
  #
  # @param keys [Array<String>] The mods' keys.
  # @return [Array<Hash>] The entries, group by group in the menu's order.
  def self.world_entries(keys)
    groups = menu_groups.select { |name, _| keys.include?(MGQ_MpWorld.mod_key(name)) }
    groups.inject([]) { |all, (_, entries)| all + entries }.select { |entry| world_option?(entry) }
  end

  # Tells whether a world may set an option.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [Boolean] Whether it has values, binds no key and is not marked personal.
  def self.world_option?(entry)
    entry[:sub] && !entry[:keybind] && !entry[:personal] && entry[:key] ? true : false
  end

  # Tells why a world cannot set an option, see world_option?.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [String, nil] "keybind", "personal" or "button", nil for an option a world may set.
  def self.skip_reason(entry)
    return "keybind" if entry[:keybind]
    return "personal" if entry[:personal]

    entry[:sub] ? nil : "button"
  end

  # Sends the Mod Config options of each catalog mod this game has installed that the DLL names,
  # once a session per mod's version. Only an admin's game sends them; the World Admin tool lists
  # them. Called by the world screen whenever it reads the list.
  #
  # @param admin [Boolean] Whether the player is one of the relay's admins.
  def self.report_options(admin)
    return unless admin && defined?(NWConst::Config::MOD_CONTENTS)

    (MGQ_Multiplayer::Bridge.call(REPORT_TOPIC) || []).each do |key, _name, version|
      lines = world_entries([key]).map { |entry| option_line(entry) }.compact
      MGQ_Multiplayer::Bridge.call(OPTIONS_TOPIC, "key" => key, "version" => version, "lines" => lines)
    end
  rescue => e
    log_once(:report_options, "sending the Mod Config options failed: #{e.class}: #{e.message}")
  end

  # Writes one Mod Config option for the catalog: its key, name, type, default and choices.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [String, nil] Tab-separated fields, see ModOption.Parse in the DLL; nil for an option
  #   whose value has a type a world does not keep.
  def self.option_line(entry)
    config = NWConst::Config
    key = entry[:key]
    values = values_of(entry)
    texts = (config.const_defined?(:DATA_TEXT) && config::DATA_TEXT[key]) || {}
    default = config.const_defined?(:DEFAULT) ? config::DEFAULT[key] : nil
    default = values.first if default.nil?
    type = type_of(default)
    return nil unless type

    choices = values.map { |value| type_of(value) && [value, (texts[value] && texts[value][:name]) || value] }.compact
    ([key, short_name(entry), type, default] + choices.flatten).map { |field| dump_field(field) }.join("\t")
  end

  # Writes a field of a tab-separated line.
  #
  # @param field [Object] The field.
  # @return [String] Its text, tabs and line breaks turned into spaces.
  def self.dump_field(field)
    field.to_s.gsub(/[\t\r\n]/, " ")
  end

  # Reads the values an option can take as Mod Config Remake does: from its :values, an array or a
  # proc, or else from DATA.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [Array] The values in order, none when it has none or its proc fails.
  def self.values_of(entry)
    values = entry[:values]
    values = values.call if values.respond_to?(:call)
    config = NWConst::Config
    values ||= config::DATA[entry[:key]] if config.const_defined?(:DATA)
    values ? values.to_a : []
  rescue
    []
  end

  # Tells whether two values of an option are the same, decimals within a margin, as Mod Config
  # Remake finds a value among an option's values.
  #
  # @param one [Object] A value.
  # @param other [Object] The other value.
  # @return [Boolean] Whether they are.
  def self.same_value?(one, other)
    return one == other unless one.is_a?(Float) || other.is_a?(Float)

    (one.to_f - other.to_f).abs < 1e-6
  rescue
    false
  end

  # Lists the mods of the open world the player's game runs, which the battle server runs too for a
  # battle it hosts: each mod the world names and the player installed, but those the catalog marks
  # personal, with its kind, version and files' hashes as the catalog has them; a copy the server
  # cannot get comes without a kind. Called by MGQ_MpBattlesServed.setup_text.
  #
  # @return [Array<Array>] Each mod's key, kind, version and [path, hash] pairs.
  def self.served_mods
    return [] unless @world

    MGQ_Multiplayer::Bridge.call(SERVED_TOPIC, @world["mods"].to_s) || []
  end

  # Writes the player's options of the world's mods, which the battle server takes for a battle
  # it hosts. Called by MGQ_MpBattlesServed.setup_text.
  #
  # @return [String] "key=type:value" pairs separated by semicolons.
  def self.served_settings
    return "" unless @world

    option_pairs(MGQ_MpWorld.mods_of(@world["mods"]).map { |name| MGQ_MpWorld.mod_key(name) }).map { |_, pair| pair }.join(";")
  rescue => e
    log("writing the world's mod settings for the battle server failed: #{e.class}: #{e.message}")
    ""
  end

  # Settings.

  # Writes some mods' options as the creator's game has them, leaving out key bindings, buttons and
  # options marked personal.
  #
  # @param keys [Array<String>] The mods' keys.
  # @return [Array<Array(Symbol, String)>] Each option's key and its "key=type:value" pair.
  def self.option_pairs(keys)
    return [] unless $game_system

    world_options(keys).map { |key| (encoded = encode(option_value(key))) && [key, "#{key}=#{encoded}"] }.compact
  end

  # Lists the keys of every Mod Config entry this game has.
  #
  # @return [Array<Symbol>] The keys.
  def self.menu_keys
    return [] unless defined?(NWConst::Config::MOD_CONTENTS)

    NWConst::Config::MOD_CONTENTS.map { |entry| entry[:key] }.compact.map { |key| key.to_sym }
  end

  # Splits a world's settings into their pairs.
  #
  # @param text [String, nil] "key=type:value" pairs separated by semicolons.
  # @return [Array<Array(Symbol, String)>] Each pair's key and the pair as written.
  def self.pairs_of(text)
    text.to_s.split(";").map { |pair| key = pair.split("=", 2)[0].to_s; key.empty? ? nil : [key.to_sym, pair] }.compact
  end

  # Tells whether a world's settings are shared: an empty text leaves every player their own.
  #
  # @param text [String, nil] The world's settings.
  # @return [Boolean] Whether they are.
  def self.shared?(text)
    MGQ_Multiplayer::Bridge.call(SHARED_TOPIC, text.to_s) == true
  end

  # Reads an option's current value.
  #
  # @param key [Symbol] The option.
  # @return [Object] Its value, its default until it was changed.
  def self.option_value(key)
    value = $game_system.conf[key]
    value.nil? && defined?(NWConst::Config::DEFAULT) ? NWConst::Config::DEFAULT[key] : value
  end

  # Writes a value with its type.
  #
  # @param value [Object] The value.
  # @return [String, nil] Such as "i:1", nil for a type a world does not keep.
  def self.encode(value)
    type = type_of(value)
    type && "#{type}:#{value.to_s.gsub('%', '%25').gsub(';', '%3B').gsub('=', '%3D')}"
  end

  # Names a value's type as a world's settings write it.
  #
  # @param value [Object] The value.
  # @return [String, nil] "i", "f", "b", "y" or "s", nil for a type a world does not keep.
  def self.type_of(value)
    # Ruby 1.9's whole numbers are Fixnum or Bignum, which case finds as Integer.
    case value
    when Integer then "i"
    when Float then "f"
    when true, false then "b"
    when Symbol then "y"
    when String then "s"
    end
  end

  # Reads a value written with its type.
  #
  # @param text [String] Such as "i:1".
  # @return [Array] Whether it was readable, and the value.
  def self.decode(text)
    type, raw = text.to_s.split(":", 2)
    raw = raw.to_s.gsub('%3D', '=').gsub('%3B', ';').gsub('%25', '%')

    case type
    when "i" then raw =~ /\A-?\d+\z/ ? [true, raw.to_i] : [false, nil]
    when "f" then raw =~ /\A-?\d+(\.\d+)?(e[-+]?\d+)?\z/i ? [true, raw.to_f] : [false, nil]
    when "b" then [true, raw == "true"]
    when "y" then raw.empty? ? [false, nil] : [true, raw.to_sym]
    when "s" then [true, raw]
    else [false, nil]
    end
  end

  # Reads a world's settings.
  #
  # @param text [String, nil] "key=type:value" pairs separated by semicolons.
  # @return [Hash] The values by the options' keys, without the marker.
  def self.settings_from(text)
    pairs_of(text).each_with_object({}) do |(key, pair), values|
      next if key == MARKER_KEY

      readable, value = decode(pair.split("=", 2)[1])
      values[key] = value if readable
    end
  end

  # Lists this game's Mod Config groups as the DLL's notices name them: each option's key, its name
  # as its row shows it and the names Mod Config gives its values.
  #
  # @return [Array<Array>] Each group's name and [key, name, [[value with its type, name], ...]] options.
  def self.options_table
    texts = defined?(NWConst::Config::DATA_TEXT) ? NWConst::Config::DATA_TEXT : {}
    menu_groups.map do |name, entries|
      options = entries.select { |entry| entry[:key] }.map do |entry|
        values = (texts[entry[:key]] || {}).map { |value, text| (encoded = encode(value)) && text.is_a?(Hash) && text[:name] ? [encoded, text[:name].to_s] : nil }.compact
        [entry[:key].to_s, short_name(entry), values]
      end
      [name, options]
    end
  end

  # Hands the DLL this game's Mod Config groups, once a session, and again once mods loaded on
  # entering, whose options join them.
  #
  # @param again [Boolean] Whether to hand them although they were handed.
  def self.hand_options(again = false)
    return if @options_handed && !again

    @options_handed = true
    take(MGQ_Multiplayer::Bridge.call(GROUPS_TOPIC, options_table))
  rescue => e
    log("handing the Mod Config options to the DLL failed: #{e.class}: #{e.message}")
  end

  # The world being entered or played in.

  # Notes the world being entered: its creator, its mods and its settings, which apply once its
  # game is loaded or started. The row of Shared Mod Settings joins Mod Config.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld, nil] The world, nil when the list lacks it.
  # @param me [String] The player's id.
  # @param fresh [Boolean] Whether the list was fetched since the world screen opened.
  def self.enter_world(listed, me, fresh = true)
    forget_world
    hand_options
    world = listed && { "id" => listed.id, "name" => listed.name.to_s, "creator_id" => listed.creator_id.to_s, "creator_name" => listed.creator_name.to_s,
                        "mods" => listed.mods.to_s, "settings" => listed.settings.to_s }
    take(MGQ_Multiplayer::Bridge.call(ENTER_TOPIC, "world" => world, "me" => me.to_s, "fresh" => fresh ? true : false))
    add_row if @world
  rescue => e
    log("noting the world's mod settings failed: #{e.class}: #{e.message}")
  end

  # Takes the mods the relay tells the open world names now, whose settings the creator shares from
  # then on.
  #
  # @param mods [String] The mods as the world writes them.
  def self.take_mods(mods)
    take(MGQ_Multiplayer::Bridge.call(MODS_TOPIC, mods.to_s)) if @world
  end

  # Forgets the world, its locks, the row of Shared Mod Settings, the settings on their way, whose
  # answer the directory then drops, and the mods of its session it did not enter with yet.
  def self.forget_world
    lock([])
    remove_row
    take(MGQ_Multiplayer::Bridge.call(FORGET_WORLD_TOPIC))
    @world = nil
    @in_options = false
    @entering = nil
  end

  # Tells whether the player plays in a world they created.
  #
  # @return [Boolean] Whether they do.
  def self.own_world?
    MGQ_MpWorld.open? && @world && @world["own"] ? true : false
  end

  # Writes the world's settings into the game's options and has Mod Config Remake show them as
  # set by the world; a world that shares none sets and locks nothing. Called once a save is loaded
  # or a new game started in a world.
  def self.apply
    return unless MGQ_MpWorld.open? && @world && $game_system

    applied = @world["shared"] ? apply_text(@world["text"]) : (lock([]); [])
    take(MGQ_Multiplayer::Bridge.call(LOADED_TOPIC, own_options.merge("applied" => applied.map { |key| key.to_s })))
  rescue => e
    log("applying the world's mod settings failed: #{e.class}: #{e.message}")
  end

  # Writes the creator's options of the world's mods for the DLL, which makes them the world's
  # settings while it shares them.
  #
  # @return [Hash] "pairs", each option's [key, "key=type:value"], and "known", the key of every
  #   option this game's Mod Config has; none of either for another player.
  def self.own_options
    return { "pairs" => [], "known" => [] } unless own_world? && $game_system

    keys = MGQ_MpWorld.mods_of(@world["mods"]).map { |name| MGQ_MpWorld.mod_key(name) }
    { "pairs" => option_pairs(keys).map { |key, pair| [key.to_s, pair] }, "known" => menu_keys.map { |key| key.to_s } }
  end

  # Writes shared settings into the game's options and locks them, but for the creator.
  #
  # @param text [String] The world's settings.
  # @return [Array<Symbol>] The options written.
  def self.apply_text(text)
    settings = settings_from(text)
    before = settings.select { |key, value| !same_value?($game_system.conf[key], value) }.map { |key, value| "#{key} #{$game_system.conf[key].inspect} -> #{value.inspect}" }
    applied = apply_values(settings)
    lock(own_world? ? [] : applied)
    log("applied #{applied.size} of #{settings.size} mod setting(s) of the world#{before.empty? ? '' : ', changed ' + before.join(', ')}; #{own_world? ? 'left unlocked for the creator' : 'locked in Mod Config'}")
    applied
  end

  # Writes settings into the game's options: only those of options a world may set in a mod's
  # group of this game's Mod Config, and of those only values this game's copy of an option offers.
  #
  # A world's settings come from another game, so a key of the game's own options, of a key binding
  # or of an option marked personal must never reach the player's options.
  #
  # @param settings [Hash] The values by the options' keys.
  # @return [Array<Symbol>] The options written.
  def self.apply_values(settings)
    entries = {}
    menu_groups.each { |_, group| group.each { |entry| entries[entry[:key]] ||= entry if world_option?(entry) } }
    unknown = []
    skipped = []

    applied = settings.keys.select do |key|
      unless entries[key]
        unknown << key
        next false
      end

      values = values_of(entries[key])
      offered = values.empty? || values.any? { |value| same_value?(value, settings[key]) }
      if offered
        $game_system.conf[key] = settings[key]
      else
        skipped << "#{key}=#{settings[key].inspect} (offers #{values.map { |value| value.inspect }.join(', ')})"
      end
      offered
    end
    log("left out #{unknown.size} setting(s) of options no mod of this game lets a world set: #{unknown.join(', ')}") unless unknown.empty?
    log("left out #{skipped.size} value(s) this game's copies do not offer: #{skipped.join('; ')}") unless skipped.empty?
    applied
  end

  # Tells the Mod Config which options the world sets: the Mod Framework's options, else Mod Config
  # Remake, if it can show that.
  #
  # @param keys [Array<Symbol>] The options, none outside a world.
  def self.lock(keys)
    if defined?(Mod_Framework::Options) && Mod_Framework::Options.respond_to?(:world_keys=)
      Mod_Framework::Options.world_keys = keys
    elsif defined?(ModConfigRemake) && ModConfigRemake.respond_to?(:world_keys=)
      ModConfigRemake.world_keys = keys
    end
  end

  # Lets the options be changed again once the game went back to the title screen, unless the world
  # stays open there for its new game.
  def self.on_title_start
    forget_world unless MGQ_MpWorld.new_game_pending?
  end

  # Mod Config's row.

  # Adds the row of Shared Mod Settings to the Mod Config, the Mod Framework's or Mod Config
  # Remake's, once: every player sees whether the world shares its creator's settings, and only the
  # creator may change it.
  def self.add_row
    return unless (defined?(Mod_Framework::Options) || defined?(ModConfigRemake)) && defined?(NWConst::Config::MOD_CONTENTS)

    menu = NWConst::Config::MOD_CONTENTS
    return if menu.any? { |entry| entry[:key] == SHARED_OPTION }

    config = NWConst::Config
    config::DATA[SHARED_OPTION] = [1, 0] if config.const_defined?(:DATA)
    config::DATA_TEXT[SHARED_OPTION] = { 1 => { :name => "On", :help => ROW_ON_HELP }, 0 => { :name => "Off", :help => ROW_OFF_HELP } } if config.const_defined?(:DATA_TEXT)
    config::DEFAULT[SHARED_OPTION] = 0 if config.const_defined?(:DEFAULT)
    # Mod Config Remake's last entry is its Return.
    menu.insert([menu.size - 1, 0].max, :key => SHARED_OPTION, :name => ROW_NAME, :sub => true, :personal => true,
                    :help => lambda { MGQ_MpWorldMods.row_help }, :enable => lambda { MGQ_MpWorldMods.own_world? },
                    :on_change => lambda { |value| MGQ_MpWorldMods.switch(value) })
  end

  # Takes the row of Shared Mod Settings out of Mod Config Remake.
  def self.remove_row
    NWConst::Config::MOD_CONTENTS.delete_if { |entry| entry[:key] == SHARED_OPTION } if defined?(NWConst::Config::MOD_CONTENTS)
  end

  # Tells what the row of Shared Mod Settings does, to the creator or to another player.
  #
  # @return [String] The help.
  def self.row_help
    return "Whether every player in this world plays with your options of its mods. Their own saves keep their own.\r\n←/→ Toggle" if own_world?

    "#{@world ? MGQ_Multiplayer.clean(@world['creator_name']) : 'The creator'} created this world and chose this. While On, the world's mod options are set for you here."
  end

  # Shows in the row whether the world shares its settings, or will once the request on its way
  # arrived.
  #
  # @param shared [Boolean] Whether it does, as the DLL tells it.
  def self.show_row_value(shared = @world && @world["latest_shared"])
    $game_system.conf[SHARED_OPTION] = shared ? 1 : 0 if $game_system && @world
  end

  # Draws Mod Config anew, should the player be in it.
  def self.refresh_menu
    scene = SceneManager.scene
    scene.refresh_mod_config if scene.respond_to?(:refresh_mod_config)
  rescue
  end

  # Turns sharing on or off. Called by the row of Shared Mod Settings once the creator changed it.
  #
  # @param value [Integer] 1 for On, 0 for Off.
  def self.switch(value)
    take(MGQ_Multiplayer::Bridge.call(WANT_TOPIC, own_options.merge("reason" => "switch", "on" => value.to_i == 1)))
  rescue => e
    log("changing Shared Mod Settings failed: #{e.class}: #{e.message}")
  end

  # Makes the creator's changed options the world's settings while it shares them. Called as the
  # options screen closes.
  def self.sync_options
    take(MGQ_Multiplayer::Bridge.call(WANT_TOPIC, own_options.merge("reason" => "options"))) if own_world?
  end

  # The DLL's steps.

  # Takes the DLL's answer: the world as it stands now, and plays the steps it hands.
  #
  # @param reply [Hash, nil] "world" and "steps", see SharedSettingsSync in the DLL; nil when it did
  #   not answer.
  def self.take(reply)
    return unless reply.is_a?(Hash)

    @world = reply["world"]
    reply["steps"].each { |step| play(step) }
  end

  # Plays one step of the DLL.
  #
  # @param step [Array] Its kind and values: "notify" with the lines, "apply" or "apply_live" with
  #   the settings, "unlock", "broadcast" with the settings and their checksum, "tell" with the seat,
  #   the checksum their game holds, the world's and its settings, "row" with whether it shares.
  def self.play(step)
    kind, first, second, third, fourth = step
    case kind
    when "notify" then notify(first)
    when "apply" then apply_text(first) if $game_system
    when "unlock" then lock([])
    when "apply_live"
      applied = $game_system ? apply_text(first) : []
      take(MGQ_Multiplayer::Bridge.call(APPLIED_TOPIC, "keys" => applied.map { |key| key.to_s }))
    when "broadcast" then broadcast(first, second)
    when "tell" then tell(first, second, third, fourth)
    when "row"
      show_row_value(first)
      refresh_menu
    end
  rescue => e
    log_once([:step, kind], "playing the DLL's step #{kind} failed: #{e.class}: #{e.message}")
  end

  # Live changes.

  # Tells every player in the world the settings the relay took, so they apply at once.
  #
  # @param text [String] The settings.
  # @param crc [String] Their checksum.
  def self.broadcast(text, crc)
    return unless defined?(MGQ_MpOverworldSync)

    sent = MGQ_MpOverworldSync.tell(-1, { LIVE_FIELD => crc }, text)
    log(sent ? "told every player in the world its new mod settings" : "could not tell the players the new mod settings; each hears of them from the creator's next state")
  end

  # Tells another player the world's settings, which their game holds otherwise.
  #
  # @param seat [Integer] The player's seat.
  # @param theirs [String] The checksum of the settings their game holds.
  # @param mine [String] The checksum of the world's settings.
  # @param text [String] The world's settings.
  def self.tell(seat, theirs, mine, text)
    return unless defined?(MGQ_MpOverworldSync) && MGQ_MpOverworldSync.tell(seat, { LIVE_FIELD => mine }, text)

    MGQ_Multiplayer::Bridge.call(TOLD_TOPIC, "seat" => seat, "theirs" => theirs, "mine" => mine)
    log("told the player on seat #{seat} the world's mod settings, which their game had otherwise")
  end

  # Hands the DLL another player's state, which tells the settings their game holds. Called
  # whenever another player tells their state.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.on_observe(peer)
    return unless own_world?

    take(MGQ_Multiplayer::Bridge.call(OBSERVE_TOPIC, "seat" => peer.seat, "crc" => peer.state[STATE_FIELD].to_s))
  rescue => e
    log_once(:observe, "telling a player the mod settings failed: #{e.class}: #{e.message}")
  end

  # Has the DLL forget what another player was told, so whoever takes their seat next is checked
  # anew. Called as a player leaves the world.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.on_leave(peer)
    MGQ_Multiplayer::Bridge.call(LEAVE_TOPIC, peer.seat)
  rescue => e
    log_once(:leave, "forgetting a player who left failed: #{e.class}: #{e.message}")
  end

  # Adds what the player's game holds of the world's settings to the state it tells the others.
  #
  # @return [Hash] The checksum of the settings, none outside a world.
  def self.state_fields
    @world && MGQ_MpWorld.open? ? { STATE_FIELD => @world["crc"] } : {}
  end

  # Hands the DLL the settings the world's creator sent, which it applies at once while a save of
  # the world is loaded, and otherwise once one is.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent them.
  # @param message [Hash] The message, the settings under :payload.
  def self.take_live(peer, message)
    return unless @world && MGQ_MpWorld.open? && !@world["own"]

    take(MGQ_Multiplayer::Bridge.call(LIVE_TOPIC, "sender" => peer ? peer.state["id"].to_s : "", "name" => peer ? peer.state["name"].to_s : "", "text" => message[:payload].to_s))
  rescue => e
    log("taking the world's new mod settings failed: #{e.class}: #{e.message}")
  end

  # Telling the player.

  # Shows a message of the DLL in the notification box, in the lines it broke it into.
  #
  # @param lines [Array<String>] The lines.
  def self.notify(lines)
    return unless defined?(MGQ_MpNotices)

    NOTICE_LINES.times { |index| MGQ_MpNotices.drop([NOTICE_KEY, index], "a newer one replaces it") }
    (lines.size - 1).downto(0) { |index| MGQ_MpNotices.message([NOTICE_KEY, index], lines[index], NOTICE_FRAMES) }
  end

  # What the world screen's details say about a world's mod settings.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @param me [String] The player's id.
  # @return [String] Such as "Mod settings: shared by Creator (Level Cap)", naming the mods whose
  #   options the settings hold as this game's Mod Config groups them.
  def self.details_text(listed, me)
    hand_options
    MGQ_Multiplayer::Bridge.call(DETAILS_TOPIC, "settings" => listed.settings.to_s, "creator_id" => listed.creator_id.to_s, "creator_name" => listed.creator_name.to_s, "me" => me.to_s).to_s
  end

  # Takes the DLL's steps whenever it has some, and sends the creator's changed options once they
  # leave the options screen. Called every frame of every scene.
  def self.tick
    take(MGQ_Multiplayer::Bridge.call(STEP_TOPIC)) if MGQ_MpWorld::Changes.take?(MGQ_MpWorld::Changes::SETTINGS)
    watch_options
    follow_kick
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Sends the creator's changed options once they leave the options screen.
  def self.watch_options
    in_options = defined?(Scene_Config) && SceneManager.scene.is_a?(Scene_Config) ? true : false
    left = @in_options && !in_options
    @in_options = in_options
    sync_options if left
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # As the title screen starts, Mod Config Remake stops showing a world's settings.
  MGQ_MpHooks.before(Scene_Title, :start, "world_mods") { MGQ_MpWorldMods.on_title_start }

  # The title screen opens the world screen to enter a world again after a restart for its mods.
  MGQ_MpHooks.after(Scene_Title, :update, "world_mods") { MGQ_MpWorldMods.on_title_update(self) }

  # Every scene follows the settings on their way, the options screen above all.
  MGQ_MpHooks.after(Scene_Base, :update, "world_mods") { MGQ_MpWorldMods.tick }
rescue => e
  MGQ_MpWorldMods.log("title hooks FAILED: #{e.class}: #{e.message}")
end

# What the world's shared settings take part in of the world, through overworld_sync.rbx, which
# loads after this script under the Mod Framework.

begin
  if defined?(MGQ_Multiplayer::Stages)
    MGQ_Multiplayer::Stages.when_loaded("world_mods") { MGQ_MpWorldMods.join_world }
  else
    MGQ_MpWorldMods.join_world
  end
rescue => e
  MGQ_MpWorldMods.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.

begin
  # A save loaded or a new game started in a world takes the world's mod settings. The newest
  # translation's plugins load after the Patch folder and replace load_game, which still calls
  # load_game_without_rescue.
  MGQ_MpHooks.around(DataManager.singleton_class, :load_game_without_rescue, "world_mods") do |_manager, _args, original|
    loaded = original.call
    MGQ_MpWorldMods.apply if loaded
    loaded
  end

  MGQ_MpHooks.after(DataManager.singleton_class, :setup_new_game, "world_mods") { MGQ_MpWorldMods.apply }
rescue => e
  MGQ_MpWorldMods.log("save hooks FAILED: #{e.class}: #{e.message}")
end
