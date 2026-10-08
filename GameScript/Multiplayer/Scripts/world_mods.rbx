#----------------------------------------------------------------
#  world_mods.rbx
#
#  Changelog:
#      Paulinchen  2026-10-08: Let the creator share their mod settings or not through a row of Mod Config every player sees, which replaced the button
#                            - Sent the creator's options of the world's mods as its settings whenever they change while it shares them, keeping those the creator's game does not know
#                            - Told every player in the world the new settings at once, and a player whose game holds others as they tell their state
#                            - Told the players what a world that shares its settings sets for them, as they play and as it changes
#                            - Left out a value the player's copy of an option does not offer, and set and locked nothing in a world that shares none
#                            - Wrote every mod's Mod Config options into a file for the World Admin tool, then quit, when started for it
#                            - Opened the options dump's file by its name alone in the game's folder, or in UTF-8, so a path outside ASCII works
#                            - Kept the settings the relay took last over a list from before them, and checked a player anew who takes a seat someone left
#                            - Said when settings could not be sent or got no answer, and kept every notice within three lines that fit the box
#                            - Named the stay's settings anew instead of a change when they arrive right after the load, and kept what did not fit in it
#                            - Counted and named only the options this game's Mod Config has, and said when a world shares none yet
#                            - Applied only settings of options a world may set in a mod's group of this game's Mod Config, never the game's own options
#                            - Kept the world to enter when the game cannot start itself again under Wine or Proton, for the start the player makes by hand
#                            - Took only the directory's answer to its own settings, sending them again when another request took its place, and forgot them with the world
#      Paulinchen  2026-10-07: Sent the Mod Config options of every installed catalog mod, whatever its version, until the relay holds the current version's
#                            - Logged a catalog unknown at the first read too
#                            - Followed a new game through an after block, since the hook only applies the world's mods
#                            - Named the DLL's exports alone, their signatures living in Multiplayer.rb
#                            - Logged each required mod's check, the catalog read, the downloads, the restart and rejoin, and the settings taken, applied or left out
#      Paulinchen  2026-10-06: Said a world needs mods that are missing or in another version, since some may not be installed at all
#                            - Asked a scene directly whether it changes, since the game makes that public
#                            - Kept the catalog while the list is fetched again, so a mod is never let in by name only meanwhile
#                            - Left catalog mods the relay could not read yet out of the catalog, so they no longer keep every game out
#                            - Sent the Mod Config options once a session, not each time the world screen opens
#                            - Read an option's values from its :values too, as Mod Config Remake does
#                            - Kept the world's settings within the 2000 characters the relay takes, and told the creator what was left out
#                            - Left mod names longer than the relay takes out of the creator's hashes
#                            - Sent the Mod Config options of each catalog mod this admin's game has in the catalog's version, for the World Admin tool
#                            - Added a button to Mod Config for the world's creator, who sets the world's mod settings from their own, and left the creator's options unlocked
#                            - Took the world's mod settings from every mod it names, listed ones too, not only the required ones
#                            - Read decimal settings with a plus sign in their exponent, as Ruby writes large ones
#                            - Applied the world's mod settings from load_game_without_rescue, which the newest translation's load_game still calls
#                            - Checked a link to a zip of a release file by file, like an upload
#                            - Created
#
#----------------------------------------------------------------

# A world's mods: the ones its creator marked as required, which every game that enters must have
# in the same version, and the creator's settings of every mod it names, required or listed, which
# hold while the player is in the world.
#
# The relay's mod catalog, which only its admins fill, names the current version of each mod it
# knows and the hashes of its files. A game whose copy is missing or differs cannot enter, and may
# download the world's version, checked file by file against the catalog, then start again and
# enter the world. A required mod outside the catalog is checked against the hash of the creator's
# copy, which the creator's game sent with the world; that one the player gets from its author.
#
# A world shares its creator's settings or leaves every player their own, as its creator chose.
# The settings come from the options each mod offers in Mod Config Remake, which the game keeps in
# each save: a world has saves of its own, so the player's own saves keep their own settings, and
# Mod Config Remake shows the world's as set by the world. While the creator plays in a world that
# shares them, their options become its settings as they change, and every player in it gets them
# at once. Mods build those options as they load, so an admin's game reads them for the catalog,
# and a game the World Admin tool starts for them writes them into a file and quits.
#
# world_screen.rbx, which loads later, checks and installs from the world screen. It must never
# interrupt the game, so every entry point rescues.
module MGQ_MpWorldMods
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "world mods"

  # Bytes the DLL may write the catalog into at first. A larger catalog asks for a larger buffer.
  CATALOG_SIZE = 65_536

  # Seconds between two readings of the catalog.
  CATALOG_SECONDS = 1.0

  # Bytes of a file's hash and its terminating zero.
  HASH_SIZE = 65

  # The setting in Player.ini that names the world to enter again once the game started anew.
  REJOIN_SETTING = "rejoin"

  # The row of Mod Config that tells whether the world shares its creator's settings.
  SHARED_OPTION = :mgq_mp_shared_mod_settings

  # The row's name, in Monster Girl Quest! Online's group.
  ROW_NAME = "[Monster Girl Quest! Online] Shared Mod Settings"

  # What the row's values say.
  ROW_ON_HELP = "Every player here plays with the creator's mod options."
  ROW_OFF_HELP = "Each player here sets their own mod options."

  # Monster Girl Quest! Online's own group in Mod Config, which the options dump leaves out.
  ONLINE_GROUP = "Monster Girl Quest! Online"

  # The pair that starts the settings of a world that shares them. Released games skip it, since
  # they cannot read its type.
  MARKER = "@shared=o:1"

  # The marker's key, as settings_from reads it.
  MARKER_KEY = :"@shared"

  # The kind of directory action that sends the settings.
  SHARE_ACTION = "settings"

  # The field that marks the creator's message of the world's new settings.
  LIVE_FIELD = "world_mods"

  # The field of a player's state that holds the checksum of the settings their game applies.
  STATE_FIELD = "mod_settings"

  # Frames before settings that could not be sent are tried again, two seconds.
  RETRY_FRAMES = 120

  # Frames the relay may take to answer settings sent, thirty seconds.
  SEND_FRAMES = 1800

  # The environment variable that names the file the World Admin tool reads the options from.
  DUMP_SETTING = "MGQMP_OPTIONS_DUMP"

  # The options dump's first line, its format.
  DUMP_HEADER = "mgqmp-options\t1"

  # An option's name that opens its mod's group, and one that joins the group above, as Mod
  # Config Remake reads them.
  MOD_NAME = /\A\s*\[([^\]]+)\]\s*/
  INDENTED = /\A(\s|->)/

  # What the notification box says, its key, how long, and how many lines of how many characters,
  # which leaves room for two invites in its five rows.
  NOTICE_KEY = :world_mod_settings
  NOTICE_FRAMES = 600
  NOTICE_LINES = 3
  # The box draws 378 pixels wide at size 16, where the game's VL Gothic has Latin letters 8 pixels
  # wide; a longer line is squeezed.
  NOTICE_LINE_CHARS = 46

  # Most mods and changed options a notice names before it counts the rest.
  NAMED_MODS = 2
  NAMED_CHANGES = 2

  # What the player is told, the creator's name, the options or the changes filled in.
  STAY_TEXT = "%s shares mod settings here: %s set for you. Your own saves keep yours."
  STAY_EMPTY_TEXT = "%s shares mod settings here, but none are set for your mods yet."
  STAY_CREATOR_TEXT = "You share your options of %s with every player here."
  STAY_CREATOR_NONE_TEXT = "You share your mod settings here, but this world's mods have no options to share."
  NOW_SHARED_TEXT = "%s now shares mod settings: %s set for you. Your own saves keep yours."
  NOW_SHARED_EMPTY_TEXT = "%s now shares mod settings, but none are set for your mods yet."
  CHANGED_TEXT = "%s changed the shared mod settings: %s."
  NO_LONGER_TEXT = "%s stopped sharing mod settings: you can set your own options again. Your save here keeps the values so far."
  CREATOR_ON_TEXT = "Shared Mod Settings on: players here get your options of %s."
  CREATOR_ON_NONE_TEXT = "Shared Mod Settings on, but this world's mods have no options to share."
  CREATOR_OFF_TEXT = "Shared Mod Settings off: every player here sets their own mod options again."
  CREATOR_CHANGE_TEXT = "Shared with every player: %s."
  FAILED_TEXT = "The world's mod settings could not be saved: %s"
  NO_ANSWER_TEXT = "the relay did not answer."
  NOT_SENT_TEXT = "The world's mod settings could not be sent yet. Trying again in a moment."
  LEFT_OUT_TEXT = "%d option(s) did not fit and were left out."

  # The kinds of mods that come as a zip whose files go to their paths inside Patch.
  ZIP_KINDS = %w(upload zip)

  # Most characters of a world's settings, as many as the relay takes.
  MAX_SETTINGS_CHARS = 2000

  # Longest mod name the relay takes among the creator's hashes.
  MAX_HASH_NAME_CHARS = 100

  # A mod of the catalog.
  #
  # @!attribute key [String] Its key, as MGQ_MpWorld.mod_key makes it.
  # @!attribute name [String] Its name.
  # @!attribute kind [String] "link" for a script the relay follows on GitHub, "zip" for a zip of a release there, "upload" for a mod of several files an admin uploaded.
  # @!attribute version [String] Its current version.
  # @!attribute files [Hash] Its current files' hashes, a script's by its name, a zip's or an upload's by each path inside Patch.
  # @!attribute versions [Array<Array>] Each version the relay saw and its files' hashes, newest first.
  # @!attribute options_version [String, nil] The version whose Mod Config options the relay keeps, nil before an admin's game sent any.
  Mod = Struct.new(:key, :name, :kind, :version, :files, :versions, :options_version)

  # A required mod this game lacks or has in another version.
  #
  # @!attribute name [String] The mod's name, as the world writes it.
  # @!attribute yours [String] This game's version: "not installed", the version, "unknown" or "differs".
  # @!attribute worlds [String, nil] The world's version, nil when only the creator's hash tells it.
  # @!attribute mod [Mod, nil] The catalog's mod, which can be downloaded; nil for a mod outside the catalog.
  # @!attribute target [String, nil] Where a link mod's script goes, relative to the game's folder.
  Row = Struct.new(:name, :yours, :worlds, :mod, :target) do
    # Tells whether the world's version can be downloaded.
    #
    # @return [Boolean] Whether it can.
    def downloadable?
      !mod.nil?
    end

    # Describes the difference for the player.
    #
    # @return [String] Such as "Level Cap: yours 1.0.0, the world's 1.1.0".
    def text
      return "#{name}: yours differs from the world creator's copy" if worlds.nil? && yours == "differs"
      return "#{name}: not installed" if worlds.nil?

      yours == "not installed" ? "#{name}: not installed, the world's #{worlds}" : "#{name}: yours #{yours}, the world's #{worlds}"
    end
  end

  @hashes = {}
  @reported = {}
  @confirmed = {}
  @told_peers = {}
  # Not nil, so an unknown catalog is logged at the first read too.
  @logged_catalog = false

  # Reads the relay's mod catalog as fetched with the world list, at most once a second, since the
  # world screen asks every frame.
  #
  # @return [Array<Mod>, nil] The mods, nil while the catalog is unknown, so the game checks only whether required mods are installed.
  def self.catalog
    return @catalog if @catalog_read && Time.now - @catalog_read < CATALOG_SECONDS

    @catalog_read = Time.now
    text = MGQ_Multiplayer::Link.read('mp_mods_list', CATALOG_SIZE)
    return @catalog if text == @catalog_text

    @catalog_text = text
    state = MGQ_Multiplayer::Link.parse(text)
    payload = state[:payload].to_s

    case state["state"]
    when "ready" then @catalog = parse(payload)
    # The DLL hands out the catalog it had while it fetches the list again.
    when "loading" then @catalog = parse(payload) unless payload.empty?
    else @catalog = nil
    end
    log_catalog(state["state"])
    @catalog
  rescue => e
    log_once(:catalog, "reading the mod catalog failed: #{e.class}: #{e.message}")
    nil
  end

  # Logs the catalog whenever what it holds changed.
  #
  # @param state [String, nil] How the DLL's list stands.
  def self.log_catalog(state)
    seen = @catalog && @catalog.map { |mod| [mod.key, mod.version, mod.kind, mod.options_version] }
    return if seen == @logged_catalog

    @logged_catalog = seen
    return log("mod catalog unknown (#{state == 'failed' ? 'the list did not arrive' : "list #{state.inspect}"}): required mods are only checked for being installed") unless @catalog

    mods = @catalog.map { |mod| "#{mod.name} #{mod.version} (#{mod.kind}, #{mod.files.size} file(s))" }
    log("mod catalog (list #{state}): #{@catalog.size} mod(s)#{mods.empty? ? '' : ': ' + mods.join(', ')}")
  end

  # Reads the catalog's lines.
  #
  # @param text [String] One line per mod and version, see WorldDirectory.DescribeMods in the DLL.
  # @return [Array<Mod>] The mods, without those the relay could not read yet, which have no
  #   version and so count as mods outside the catalog.
  def self.parse(text)
    mods = []

    text.split("\n").each do |line|
      fields = line.split("\t", -1)

      case fields[0]
      when "mod"
        mod = Mod.new(fields[1], fields[2].to_s, fields[3].to_s, fields[4].to_s, files_of(fields[5..-1]), [])
        mods.push(mod) unless mod.version.empty? || mod.files.empty?
      when "old"
        mod = mods.find { |known| known.key == fields[1] }
        mod.versions.push([fields[2].to_s, files_of(fields[3..-1])]) if mod
      when "opts"
        mod = mods.find { |known| known.key == fields[1] }
        mod.options_version = fields[2].to_s if mod
      end
    end

    mods
  end

  # Reads files and their hashes from a line's fields.
  #
  # @param fields [Array<String>] Each file's name or path, then its hash.
  # @return [Hash] The hashes by name or path.
  def self.files_of(fields)
    files = {}
    fields.to_a.each_slice(2) { |name, hash| files[name] = hash if name && hash }
    files
  end

  # Finds the catalog's mod for a name as a world writes it.
  #
  # @param name [String] The mod's name.
  # @param mods [Array<Mod>, nil] The catalog.
  # @return [Mod, nil] The mod, nil when the catalog lacks it.
  def self.mod_named(name, mods = catalog)
    key = MGQ_MpWorld.mod_key(name)
    (mods || []).find { |mod| mod.key == key }
  end

  # Hashes an installed file the way the catalog does, through the DLL.
  #
  # @param path [String] The file, relative to the game's folder.
  # @return [String, nil] The hash, nil when the file is missing or cannot be read.
  def self.hash_of(path)
    return @hashes[path] if @hashes.key?(path)

    buffer = "\0" * HASH_SIZE
    length = MGQ_Multiplayer::Link.function('mp_mod_hash').call(path + "\0", buffer, buffer.size)
    @hashes[path] = length > 0 ? buffer[0, length] : nil
  rescue => e
    log_once(:hash, "hashing an installed mod failed: #{e.class}: #{e.message}")
    nil
  end

  # Forgets what was read of the installed mods and of the catalog, as the world screen opens or
  # after an install.
  def self.forget_installed
    @hashes = {}
    @catalog_read = nil
    MGQ_MpWorld.forget_installed
  end

  # Lists the required mods of a world that this game lacks or has in another version.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Array<Row>] The mods, none when every one matches.
  def self.differing(listed)
    mods = catalog
    creator = hashes_of(listed.mod_hashes)
    MGQ_MpWorld.required_mods(listed.mods).map { |name| row_for(name, mod_named(name, mods), creator) }.compact
  end

  # Checks one required mod.
  #
  # @param name [String] The mod's name, as the world writes it.
  # @param mod [Mod, nil] The catalog's mod, nil when the catalog lacks it.
  # @param creator [Hash] The creator's hashes of mods outside the catalog, by key.
  # @return [Row, nil] The difference, nil when this game's copy matches.
  def self.row_for(name, mod, creator)
    return zip_row(name, mod) if mod && ZIP_KINDS.include?(mod.kind)
    return link_row(name, mod) if mod
    return Row.new(name, "not installed", nil, nil, nil) unless MGQ_MpWorld.installed_mod?(name)

    expected = creator[MGQ_MpWorld.mod_key(name)]
    path = expected && MGQ_MpWorld.installed_path(name)
    return nil unless path

    hash_of(path) == expected ? nil : Row.new(name, "differs", nil, nil, nil)
  end

  # Checks a link mod's script.
  #
  # @param name [String] The mod's name, as the world writes it.
  # @param mod [Mod] The catalog's mod.
  # @return [Row, nil] The difference, nil when this game's script is the current one.
  def self.link_row(name, mod)
    file, current = mod.files.first
    path = MGQ_MpWorld.installed_path(name)
    return Row.new(name, "not installed", mod.version, mod, "#{MGQ_MpWorld::PATCH_DIR}/#{file}") unless path

    hash = hash_of(path)
    return nil if hash == current

    Row.new(name, version_of(mod, file => hash) || "unknown", mod.version, mod, path)
  end

  # Checks the files of a mod that comes as a zip.
  #
  # @param name [String] The mod's name, as the world writes it.
  # @param mod [Mod] The catalog's mod.
  # @return [Row, nil] The difference, nil when every file is the current one.
  def self.zip_row(name, mod)
    hashes = {}
    mod.files.each_key { |path| hashes[path] = hash_of("#{MGQ_MpWorld::PATCH_DIR}/#{path}") }
    return nil if hashes == mod.files
    return Row.new(name, "not installed", mod.version, mod, nil) if hashes.values.compact.empty?

    Row.new(name, version_of(mod, hashes) || "unknown", mod.version, mod, nil)
  end

  # Names the version whose files a copy's hashes are.
  #
  # @param mod [Mod] The catalog's mod.
  # @param hashes [Hash] The copy's hashes.
  # @return [String, nil] The version, nil when the relay never saw this copy.
  def self.version_of(mod, hashes)
    found = mod.versions.find { |_, files| files == hashes }
    found && found[0]
  end

  # Reads the creator's hashes of mods outside the catalog.
  #
  # @param text [String, nil] "name=hash" pairs separated by semicolons.
  # @return [Hash] The hashes by the mods' keys.
  def self.hashes_of(text)
    text.to_s.split(";").each_with_object({}) do |pair, hashes|
      name, hash = pair.split("=", 2)
      hashes[MGQ_MpWorld.mod_key(name)] = hash if name && hash
    end
  end

  # Logs how each required mod of a world compares with this game's, as the player enters it.
  #
  # @param world [String] The world's name.
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @param rows [Array<Row>] The mods that differ, see differing.
  def self.log_check(world, listed, rows)
    required = MGQ_MpWorld.required_mods(listed.mods)
    return log("mod check of #{world}: no required mods (mods \"#{listed.mods}\")") if required.empty?

    creator = hashes_of(listed.mod_hashes)
    results = required.map do |name|
      row = rows.find { |candidate| candidate.name == name }
      next "#{row.text}#{row.downloadable? ? ', downloadable' : ', from its author only'}" if row

      mod = mod_named(name)
      if mod
        "#{name}: matches #{mod.version}"
      elsif creator[MGQ_MpWorld.mod_key(name)]
        "#{name}: matches the creator's copy"
      else
        "#{name}: installed, not compared (outside the catalog, no creator's hash)"
      end
    end
    log("mod check of #{world}: #{rows.empty? ? 'all match' : "#{rows.size} differ"}#{catalog ? '' : ' (catalog unknown)'}: #{results.join('; ')}")
  rescue => e
    log("logging the mod check failed: #{e.class}: #{e.message}")
  end

  # Writes the creator's hashes of the required mods outside the catalog, for a world being made
  # or changed. A mod the creator's game lacks, or whose name is longer than the relay takes, is
  # left out, so it is only checked for being installed.
  #
  # @param mods [String] The mods as the creator wrote them.
  # @return [String] "name=hash" pairs separated by semicolons.
  def self.creator_hashes(mods)
    known = catalog
    MGQ_MpWorld.required_mods(mods).map do |name|
      next if mod_named(name, known) || name =~ /[=;]/ || name.size > MAX_HASH_NAME_CHARS

      path = MGQ_MpWorld.installed_path(name)
      hash = path && hash_of(path)
      log("creator's hash of #{name} left out: #{path ? 'it could not be read' : 'not installed here'}") unless hash
      hash && "#{name}=#{hash}"
    end.compact.join(";")
  rescue => e
    log("hashing the required mods failed: #{e.class}: #{e.message}")
    ""
  end

  # Tells the player what differs, in the world screen's lines.
  #
  # @param world [String] The world's name.
  # @param rows [Array<Row>] The mods that differ.
  # @return [String] The text.
  def self.summary(world, rows)
    names = rows.map { |row| row.downloadable? ? row.name : "#{row.name} (get it from its author)" }
    action = rows.all? { |row| row.downloadable? } ? " Download them and restart?" : ""
    "#{world} needs mods that are missing or in another version here: #{names.join(', ')}.#{action}"
  end

  # Installs the world's versions of mods from the catalog. The DLL checks every file first.
  #
  # @param rows [Array<Row>] The mods, each downloadable.
  # @return [Boolean] Whether the installation started.
  def self.install(rows)
    lines = rows.map { |row| "#{row.mod.key}\t#{row.target}" }.join("\n")
    started = MGQ_Multiplayer::Link.function('mp_mods_install').call(lines + "\0") == 1
    described = rows.map { |row| "#{row.name} #{row.yours} -> #{row.worlds}#{row.target ? " into #{row.target}" : ''}" }.join(", ")
    log(started ? "downloading #{described}" : "the download of #{described} could not start")
    started
  end

  # Starts the game again so the installed mods load, and enters the world once it is back.
  #
  # Under Wine or Proton the game cannot start itself again, so the world stays noted for the
  # start the player makes by hand.
  #
  # @param world_id [String] The world to enter again.
  # @return [Symbol] :restarting when the game closes now to start again, :by_hand under Wine or
  #   Proton, where the player starts it again, :failed when it could not and stays open.
  def self.restart(world_id)
    MGQ_Multiplayer::Player.store(REJOIN_SETTING, world_id)
    case MGQ_Multiplayer::Link.function('mp_restart_game').call
    when 1
      log("starting the game again, to enter world #{MGQ_MpWorld.short(world_id)} once it is back")
      :restarting
    when 2
      log("the game cannot start itself again under Wine, so the player does; world #{MGQ_MpWorld.short(world_id)} is entered once it is back")
      :by_hand
    else
      MGQ_Multiplayer::Player.store(REJOIN_SETTING, "")
      log("the game could not start itself again, so world #{MGQ_MpWorld.short(world_id)} is not entered on its own")
      :failed
    end
  end

  # Takes the world the game should enter again after a restart, once.
  #
  # @return [String, nil] The world's id, nil when there is none.
  def self.take_rejoin
    id = MGQ_Multiplayer::Player.setting(REJOIN_SETTING).to_s
    return nil if id.empty?

    MGQ_Multiplayer::Player.store(REJOIN_SETTING, "")
    id
  end

  # Writes the options dump when the World Admin tool asked for it, forgets a world the player backed
  # out of before its new game, and opens the world screen to enter a world again after a restart.
  # Called by the title screen every frame.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    return dump_and_quit if dump_requested?

    forget_world if @world && !MGQ_MpWorld.open?
    return if @rejoining || scene.scene_changing?

    id = take_rejoin
    return unless id

    unless MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated?
      return log("not entering world #{MGQ_MpWorld.short(id)} again after the restart: the DLL is missing or the mod is outdated")
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

  # Sends the Mod Config options of each catalog mod this game has installed, whatever its version,
  # unless the relay holds the current version's options or those of the version this copy is;
  # once a session per mod. Only an admin's game sends them; the World Admin tool lists them.
  # Called by the world screen whenever it reads the list.
  #
  # @param admin [Boolean] Whether the player is one of the relay's admins.
  def self.report_options(admin)
    mods = admin && defined?(NWConst::Config::MOD_CONTENTS) ? catalog : nil

    (mods || []).each do |mod|
      version = installed_version(mod)
      next if version.nil? || mod.options_version == mod.version || @reported[mod.key] == mod.version
      next if !version.empty? && mod.options_version == version

      @reported[mod.key] = mod.version
      lines = world_entries([mod.key]).map { |entry| option_line(entry) }.compact
      MGQ_Multiplayer::Link.function('mp_mods_options').call(mod.key + "\0", version + "\0", lines.join("\n") + "\0")
      log("sending #{lines.size} Mod Config option(s) of #{mod.name} #{version.empty? ? 'of no known version' : version}")
    end
  rescue => e
    log_once(:report_options, "sending the Mod Config options failed: #{e.class}: #{e.message}")
  end

  # Names the version of this game's copy of a catalog mod.
  #
  # @param mod [Mod] The catalog's mod.
  # @return [String, nil] The version; "" for a copy that matches no version the relay knows; nil
  #   when the mod is not installed.
  def self.installed_version(mod)
    row = row_for(mod.name, mod, {})
    return mod.version if row.nil?
    return nil if row.yours == "not installed"

    row.yours == "unknown" ? "" : row.yours
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

  # Options dump.

  # Tells whether the World Admin tool started the game to read its Mod Config options.
  #
  # @return [Boolean] Whether DUMP_SETTING names a file.
  def self.dump_requested?
    !ENV[DUMP_SETTING].to_s.empty?
  rescue
    false
  end

  # Writes every mod's Mod Config options into the file DUMP_SETTING names, then quits the game.
  # Called by the title screen's first update, once every mod and plugin has added its options.
  def self.dump_and_quit
    return if @dumped

    @dumped = true
    path = dump_path
    lines = begin
              dump_lines
            rescue => e
              log("reading the Mod Config options for the dump failed: #{e.class}: #{e.message}")
              ["error\t#{dump_field("#{e.class}: #{e.message}")}"]
            end
    write_dump(path, [DUMP_HEADER] + lines + ["end"])
    log("wrote #{lines.count { |line| line.start_with?('mod') }} mod(s) with #{lines.count { |line| line.start_with?('opt') }} option(s) to #{path}, quitting")
  rescue => e
    log("the options dump failed: #{e.class}: #{e.message}, quitting")
  ensure
    SceneManager.exit
  end

  # Names the file DUMP_SETTING names as RGSS can open it: by its name alone when it lies in the
  # game's folder, where the World Admin tool starts the game, and otherwise in UTF-8.
  #
  # RGSS opens only UTF-8 paths, and an absolute one outside ASCII, such as a profile folder with
  # the user's name, fails in any other encoding, which ENV hands out.
  #
  # @return [String] The path.
  def self.dump_path
    path = ENV[DUMP_SETTING].to_s
    same_folder?(File.dirname(path), Dir.pwd) ? File.basename(path) : utf8_path(path)
  end

  # Tells whether two folders are the same, whatever their slashes and case.
  #
  # @param one [String] A folder.
  # @param other [String] The other folder.
  # @return [Boolean] Whether they are.
  def self.same_folder?(one, other)
    plain = lambda { |folder| folder.to_s.dup.force_encoding("ASCII-8BIT").tr("\\", "/").downcase.chomp("/") }
    plain.call(one) == plain.call(other)
  rescue
    false
  end

  # Writes a path in UTF-8.
  #
  # @param path [String] The path, as ENV hands it out.
  # @return [String] The path in UTF-8, as it was when it cannot be converted.
  def self.utf8_path(path)
    return path if path.encoding == Encoding::UTF_8 && path.valid_encoding?

    source = path.encoding == Encoding::ASCII_8BIT || !path.valid_encoding? ? Encoding.find("locale") : path.encoding
    path.dup.force_encoding(source).encode("UTF-8")
  rescue
    path
  end

  # Writes the dump's lines of every mod's group but Monster Girl Quest! Online's own: a "mod" line,
  # then an "opt" line per option a world may set and a "skip" line with why per other option.
  #
  # A game without Mod Config raises, so the tool never takes its empty groups for mods without
  # options.
  #
  # @return [Array<String>] The lines.
  def self.dump_lines
    raise "Mod Config Remake is not loaded" unless defined?(NWConst::Config::MOD_CONTENTS)

    lines = []
    menu_groups.each do |name, entries|
      next if MGQ_MpWorld.mod_key(name) == MGQ_MpWorld.mod_key(ONLINE_GROUP)

      lines << "mod\t#{dump_field(MGQ_MpWorld.mod_key(name))}\t#{dump_field(name)}"
      entries.each do |entry|
        line = dump_line(entry)
        lines << line if line
      end
    end
    lines
  end

  # Writes the dump's line of one option.
  #
  # @param entry [Hash] The option's entry in MOD_CONTENTS.
  # @return [String, nil] "opt" with option_line's fields, or "skip" with the key and why; nil for
  #   an entry without a key.
  def self.dump_line(entry)
    key = entry[:key]
    return nil if key.nil?

    why = skip_reason(entry)
    line = why ? nil : (option_line(entry) rescue nil)
    line ? "opt\t#{line}" : "skip\t#{dump_field(key)}\t#{why || 'type'}"
  end

  # Writes the dump next to its file, then puts it in the file's place, so the tool never reads a
  # file half written.
  #
  # @param path [String] The file.
  # @param lines [Array<String>] The lines.
  def self.write_dump(path, lines)
    temporary = "#{path}.tmp"
    File.open(temporary, "wb") { |file| file.write(lines.map { |line| line.dup.force_encoding("ASCII-8BIT") }.join("\n") + "\n") }
    File.delete(path) if File.exist?(path)
    File.rename(temporary, path)
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

  # Writes a world's shared settings from the creator's game: the marker, the creator's options of
  # the world's mods, then the options the world sets that the creator's game does not know.
  #
  # @param mods [String] The mods as the creator wrote them.
  # @param base [String, nil] The world's settings as they are.
  # @return [Array(String, Array<Symbol>)] The settings, at most MAX_SETTINGS_CHARS of them; and
  #   the options left out since they did not fit.
  def self.shared_text(mods, base)
    wanted = MGQ_MpWorld.mods_of(mods).map { |name| MGQ_MpWorld.mod_key(name) }
    known = menu_keys
    kept = pairs_of(base).reject { |key, _| key == MARKER_KEY || known.include?(key) }
    text, left_out = fit_settings([[MARKER_KEY, MARKER]] + option_pairs(wanted) + kept)
    log("built the shared mod settings of #{wanted.join(', ')}, keeping #{kept.size} this game does not know: #{text}")
    log("left out #{left_out.size} mod setting(s) past #{MAX_SETTINGS_CHARS} characters: #{left_out.join(', ')}") unless left_out.empty?
    [text, left_out]
  end

  # Writes a world's settings shared, as they are otherwise, for the edit form, which knows no options.
  #
  # @param text [String, nil] The world's settings as they are.
  # @return [String] The marker, then the settings' pairs as far as they fit.
  def self.with_marker(text)
    fit_settings([[MARKER_KEY, MARKER]] + pairs_of(text).reject { |key, _| key == MARKER_KEY })[0]
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
    !text.to_s.strip.empty?
  end

  # Joins settings as long as they fit in MAX_SETTINGS_CHARS, leaving out each that does not.
  #
  # @param pairs [Array<Array(Symbol, String)>] Each option's key and its "key=type:value" pair.
  # @return [Array(String, Array<Symbol>)] The pairs separated by semicolons, and the options left out.
  def self.fit_settings(pairs)
    text = ""
    left_out = []

    pairs.each do |key, pair|
      joined = text.empty? ? pair : "#{text};#{pair}"
      if joined.size > MAX_SETTINGS_CHARS
        left_out.push(key)
      else
        text = joined
      end
    end
    [text, left_out]
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

  # Writes settings for the log.
  #
  # @param settings [Hash] The values by the options' keys.
  # @return [String] Such as "lv_cap=true, rate=2".
  def self.settings_text(settings)
    settings.map { |key, value| "#{key}=#{value.inspect}" }.join(", ")
  end

  # The world being entered or played in.

  # Notes the world being entered: its creator, its mods and its settings, which apply once its
  # game is loaded or started. The row of Shared Mod Settings joins Mod Config.
  #
  # A list from before the world screen opened may predate settings this game saved since, which
  # would otherwise go back to every player the creator meets.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld, nil] The world, nil when the list lacks it.
  # @param me [String] The player's id.
  # @param fresh [Boolean] Whether the list was fetched since the world screen opened.
  def self.enter_world(listed, me, fresh = true)
    forget_world
    return log("entering a world the list lacks: no mod settings apply") unless listed

    own = !me.to_s.empty? && listed.creator_id == me
    text = listed.settings.to_s
    if fresh
      @confirmed.delete(listed.id)
    elsif @confirmed.key?(listed.id) && @confirmed[listed.id] != text
      log("the list of world #{MGQ_MpWorld.short(listed.id)} may be older than the mod settings the relay took from this game last, which count")
      text = @confirmed[listed.id]
    end
    @world = { :id => listed.id, :name => listed.name.to_s, :creator_id => listed.creator_id.to_s, :creator_name => MGQ_Multiplayer.clean(listed.creator_name),
               :mods => listed.mods.to_s, :text => text, :own => own }
    add_row
    log("entering #{own ? "the player's own world" : 'a world'} #{MGQ_MpWorld.short(listed.id)}: " \
        "#{shared?(@world[:text]) ? "it shares #{settings_from(@world[:text]).size} mod setting(s): #{settings_text(settings_from(@world[:text]))}" : "each player keeps their own mod settings"}")
  end

  # Notes the settings the relay took from this game for a world, which count over a list from
  # before them. Called as the relay took them, from the world or from the world screen.
  #
  # @param id [String] The world.
  # @param text [String] The settings.
  def self.confirmed(id, text)
    @confirmed[id] = text.to_s
  end

  # Forgets the world, its locks, the row of Shared Mod Settings and the settings on their way,
  # whose answer the directory then drops.
  def self.forget_world
    log("forgot the mod settings of world #{MGQ_MpWorld.short(@world[:id])}") if @world
    lock([])
    remove_row
    MGQ_MpWorld::Directory.release(@sending[:ticket]) if @sending
    @world = nil
    @loaded = false
    @stay_noticed = false
    @stay_at = nil
    @told_peers = {}
    @wanted = nil
    @sending = nil
    @not_sent_told = false
    @in_options = false
  end

  # Tells whether the player plays in a world they created.
  #
  # @return [Boolean] Whether they do.
  def self.own_world?
    MGQ_MpWorld.open? && @world && @world[:own] ? true : false
  end

  # Writes the world's settings into the game's options and has Mod Config Remake show them as
  # set by the world; a world that shares none sets and locks nothing. Called once a save is loaded
  # or a new game started in a world.
  def self.apply
    return unless MGQ_MpWorld.open? && @world && $game_system

    @loaded = true
    show_row_value
    unless shared?(@world[:text])
      lock([])
      return log("world #{MGQ_MpWorld.short(@world[:id])} does not share mod settings: every player keeps their own")
    end

    applied = apply_text(@world[:text])
    # The creator's notice names what sync makes the world's settings, and what did not fit.
    sync(:load)
    notice_stay(applied)
  rescue => e
    log("applying the world's mod settings failed: #{e.class}: #{e.message}")
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

  # Tells Mod Config Remake which options the world sets, if it can show that.
  #
  # @param keys [Array<Symbol>] The options, none outside a world.
  def self.lock(keys)
    ModConfigRemake.world_keys = keys if defined?(ModConfigRemake) && ModConfigRemake.respond_to?(:world_keys=)
  end

  # Lets the options be changed again once the game went back to the title screen, unless the world
  # stays open there for its new game.
  def self.on_title_start
    forget_world unless MGQ_MpWorld.new_game_pending?
  end

  # Mod Config's row.

  # Adds the row of Shared Mod Settings to Mod Config Remake, once: every player sees whether the
  # world shares its creator's settings, and only the creator may change it.
  def self.add_row
    return unless defined?(ModConfigRemake) && defined?(NWConst::Config::MOD_CONTENTS)

    menu = NWConst::Config::MOD_CONTENTS
    return if menu.any? { |entry| entry[:key] == SHARED_OPTION }

    config = NWConst::Config
    config::DATA[SHARED_OPTION] = [1, 0] if config.const_defined?(:DATA)
    config::DATA_TEXT[SHARED_OPTION] = { 1 => { :name => "On", :help => ROW_ON_HELP }, 0 => { :name => "Off", :help => ROW_OFF_HELP } } if config.const_defined?(:DATA_TEXT)
    config::DEFAULT[SHARED_OPTION] = 0 if config.const_defined?(:DEFAULT)
    menu.insert(-2, :key => SHARED_OPTION, :name => ROW_NAME, :sub => true, :personal => true,
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

    "#{@world ? @world[:creator_name] : 'The creator'} created this world and chose this. While On, the world's mod options are set for you here."
  end

  # Shows in the row whether the world shares its settings, or will once the request on its way
  # arrived.
  def self.show_row_value
    $game_system.conf[SHARED_OPTION] = shared?(latest_text) ? 1 : 0 if $game_system && @world
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
    unless own_world?
      log("Shared Mod Settings not changed: the player is not in a world they created")
      return show_row_value
    end

    text, left_out = value.to_i == 1 ? shared_text(@world[:mods], latest_text) : ["", []]
    @left_out = left_out.size
    log("the creator turned Shared Mod Settings #{value.to_i == 1 ? 'on' : 'off'}")
    request(text, :switch)
    show_row_value
  rescue => e
    log("changing Shared Mod Settings failed: #{e.class}: #{e.message}")
  end

  # Sending the creator's settings.

  # Makes the creator's options of the world's mods its settings while it shares them, when they
  # differ from what it has. Called as a save is loaded and as the options screen closes.
  #
  # @param reason [Symbol] :load or :options.
  def self.sync(reason)
    return unless own_world? && $game_system && shared?(latest_text)

    text, left_out = shared_text(@world[:mods], latest_text)
    @left_out = left_out.size
    request(text, reason)
  end

  # The settings the world has once every request on its way arrived.
  #
  # @return [String] The settings.
  def self.latest_text
    @wanted || (@sending && @sending[:id] == (@world && @world[:id]) ? @sending[:text] : nil) || (@world ? @world[:text] : "")
  end

  # Asks the relay to take settings as the world's, once the request on its way arrived.
  #
  # @param text [String] The settings.
  # @param reason [Symbol] :switch, :load or :options.
  def self.request(text, reason)
    @wanted = text
    @wanted_reason = reason
    @retry_at = nil
    pump
  end

  # Sends the settings wanted last, unless a request is on its way or the world has them already.
  def self.pump
    return if @sending || @wanted.nil? || @world.nil?

    if @wanted == @world[:text]
      log("the world's mod settings are as wanted already, nothing sent")
      @wanted = nil
      return
    end
    return if @retry_at && @frames.to_i < @retry_at

    # A request now would drop the answer of another one nobody took yet.
    unless MGQ_MpWorld::Directory.free? && MGQ_MpWorld::Directory.set_settings(@world[:id], @wanted)
      @retry_at = @frames.to_i + RETRY_FRAMES
      log("the world's mod settings could not be sent, trying again in a moment")
      notify(NOT_SENT_TEXT) unless @not_sent_told
      @not_sent_told = true
      return
    end

    @not_sent_told = false
    @sending = { :id => @world[:id], :text => @wanted, :before => @world[:text], :reason => @wanted_reason, :left_out => @left_out.to_i, :since => @frames.to_i,
                 :ticket => MGQ_MpWorld::Directory.claim }
    @wanted = nil
  end

  # Takes the relay's answer to the settings on their way: the world has them, which every player
  # in it hears at once, or the creator is told why not. An answer another directory request took
  # the place of sends the settings again.
  def self.follow_send
    return resend unless MGQ_MpWorld::Directory.mine?(@sending[:ticket])

    action = MGQ_MpWorld::Directory.action
    if action["state"] == "busy" || action["kind"] != SHARE_ACTION
      return unless @frames.to_i - @sending[:since] > SEND_FRAMES

      log("the relay never answered the world's mod settings, giving up")
      MGQ_MpWorld::Directory.release(@sending[:ticket])
      @sending = nil
      notify(format(FAILED_TEXT, NO_ANSWER_TEXT))
      show_row_value
      return refresh_menu
    end

    MGQ_MpWorld::Directory.clear
    sent = @sending
    @sending = nil
    if action["state"] != "done"
      notify(format(FAILED_TEXT, action["error"]))
    else
      confirmed(sent[:id], sent[:text])
      if @world && @world[:id] == sent[:id]
        @world[:text] = sent[:text]
        broadcast(sent[:text])
        tell_creator(sent)
      else
        log("the relay took the mod settings of world #{MGQ_MpWorld.short(sent[:id])}, which is no longer open")
      end
    end
    show_row_value
    refresh_menu
    pump
  end

  # Sends the settings on their way again, whose answer another directory request took the place
  # of, unless newer ones wait.
  def self.resend
    sent = @sending
    @sending = nil
    log("the answer to the world's mod settings gave way to another directory request, sending them again")
    unless @wanted
      @wanted = sent[:text]
      @wanted_reason = sent[:reason]
      @left_out = sent[:left_out]
    end
  end

  # Tells the creator what the players got from the settings the relay took.
  #
  # @param sent [Hash] The request: the settings before and after, why, and how many options did not fit.
  def self.tell_creator(sent)
    was = shared?(sent[:before])
    now = shared?(sent[:text])
    # The notice of the stay that a load starts named what did not fit already.
    told = sent[:reason] == :load && stay_recent?
    left_out = now && sent[:left_out] > 0 && !told ? format(LEFT_OUT_TEXT, sent[:left_out]) : nil
    text = if was != now
             now ? creator_on_text(known_keys(settings_from(sent[:text]).keys)) : CREATOR_OFF_TEXT
           elsif now && sent[:reason] != :load && (changes = changes_text(settings_from(sent[:before]), settings_from(sent[:text])))
             format(CREATOR_CHANGE_TEXT, changes)
           end
    log("the relay took the world's mod settings (#{sent[:reason]}): #{sent[:text].empty? ? 'none, each player keeps their own' : sent[:text]}")
    message = [left_out, text].compact.join(" ")
    notify(message) unless message.empty?
  end

  # Tells the creator that sharing is on and which mods' options it shares.
  #
  # @param keys [Array<Symbol>] The creator's options the world shares.
  # @return [String] The sentence.
  def self.creator_on_text(keys)
    keys.empty? ? CREATOR_ON_NONE_TEXT : format(CREATOR_ON_TEXT, mods_text(keys))
  end

  # Live changes.

  # Tells every player in the world the settings the relay took, so they apply at once.
  #
  # @param text [String] The settings.
  def self.broadcast(text)
    return unless defined?(MGQ_MpOverworldSync)

    crc = crc_of(text)
    sent = MGQ_MpOverworldSync.tell(-1, { LIVE_FIELD => crc }, text)
    log(sent ? "told every player in the world its new mod settings" : "could not tell the players the new mod settings; each hears of them from the creator's next state")
  end

  # Tells another player the world's settings when their game holds others, as when they entered
  # with a list from before the last change. Called whenever another player tells their state.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.on_observe(peer)
    return unless own_world?

    theirs = peer.state[STATE_FIELD].to_s
    mine = crc_of(@world[:text])
    return if theirs.empty? || theirs == mine || @told_peers[peer.seat] == [theirs, mine]
    return unless MGQ_MpOverworldSync.tell(peer.seat, { LIVE_FIELD => mine }, @world[:text])

    @told_peers[peer.seat] = [theirs, mine]
    log("told #{MGQ_MpOverworldSync.who(peer)} the world's mod settings, which their game had otherwise")
  rescue => e
    log_once(:observe, "telling a player the mod settings failed: #{e.class}: #{e.message}")
  end

  # Forgets what another player was told, so whoever takes their seat next is checked anew. Called
  # as a player leaves the world.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer] The player.
  def self.on_leave(peer)
    @told_peers.delete(peer.seat)
  rescue => e
    log_once(:leave, "forgetting a player who left failed: #{e.class}: #{e.message}")
  end

  # Adds what the player's game holds of the world's settings to the state it tells the others.
  #
  # @return [Hash] The checksum of the settings, none outside a world.
  def self.state_fields
    @world && MGQ_MpWorld.open? ? { STATE_FIELD => crc_of(@world[:text]) } : {}
  end

  # Writes the checksum of settings, which tells two games' settings apart.
  #
  # @param text [String] The settings.
  # @return [String] The checksum in hexadecimal.
  def self.crc_of(text)
    Zlib.crc32(text.to_s).to_s(16)
  end

  # Takes the settings the world's creator sent: they apply at once while a save of the world is
  # loaded, and otherwise once one is.
  #
  # @param peer [MGQ_MpOverworldSync::Peers::Peer, nil] Who sent them.
  # @param message [Hash] The message, the settings under :payload.
  def self.take_live(peer, message)
    return unless @world && MGQ_MpWorld.open? && !@world[:own]

    sender = peer && peer.state["id"].to_s
    unless sender && !sender.empty? && sender == @world[:creator_id]
      return log_once([:live_refused, sender], "ignored mod settings from #{MGQ_MpOverworldSync.who(peer)}, who did not create this world")
    end

    text = message[:payload].to_s
    return if text == @world[:text]

    before = @world[:text]
    @world[:text] = text
    name = MGQ_Multiplayer.clean(peer.state["name"])
    log("#{name}, the world's creator, changed its mod settings to #{text.empty? ? 'none' : text}")
    return log("they apply once a save of the world is loaded") unless @loaded && $game_system

    apply_live(before, text, name)
  rescue => e
    log("taking the world's new mod settings failed: #{e.class}: #{e.message}")
  end

  # Applies the world's new settings at once and tells the player what changed.
  #
  # @param before [String] The settings before.
  # @param after [String] The settings now.
  # @param name [String] The creator's name.
  def self.apply_live(before, after, name)
    if shared?(after)
      applied = known_keys(apply_text(after))
      if shared?(before) && stay_recent?
        # Settings that arrive right after the load are only newer than the player's list, not a
        # change, so the notice of the stay names them anew.
        notify(stay_text(applied, name))
      elsif shared?(before)
        changes = changes_text(settings_from(before), settings_from(after))
        notify(format(CHANGED_TEXT, name, changes)) if changes
      else
        @stay_noticed = true
        notify(applied.empty? ? format(NOW_SHARED_EMPTY_TEXT, name) : format(NOW_SHARED_TEXT, name, options_text(applied)))
      end
    elsif shared?(before)
      lock([])
      notify(format(NO_LONGER_TEXT, name))
    end
    show_row_value
    refresh_menu
  end

  # Telling the player.

  # Tells the player once per stay in a world that shares its settings what that means for them.
  #
  # @param applied [Array<Symbol>] The options the world set.
  def self.notice_stay(applied)
    return if @stay_noticed

    @stay_noticed = true
    @stay_at = @frames.to_i
    notify(own_world? ? creator_stay_text : stay_text(known_keys(applied), @world[:creator_name]))
  end

  # Tells whether the notice of the stay may still show.
  #
  # @return [Boolean] Whether it was posted less than NOTICE_FRAMES ago.
  def self.stay_recent?
    @stay_at && @frames.to_i - @stay_at < NOTICE_FRAMES ? true : false
  end

  # Tells another player what the world sets for them while they play in it.
  #
  # @param keys [Array<Symbol>] The options set that this game's Mod Config has.
  # @param name [String] The creator's name.
  # @return [String] The notice.
  def self.stay_text(keys, name)
    keys.empty? ? format(STAY_EMPTY_TEXT, name) : format(STAY_TEXT, name, options_text(keys))
  end

  # Tells the creator what they share, and first how many options did not fit.
  #
  # @return [String] The notice.
  def self.creator_stay_text
    keys = known_keys(settings_from(latest_text).keys)
    text = keys.empty? ? STAY_CREATOR_NONE_TEXT : format(STAY_CREATOR_TEXT, mods_text(keys))
    @left_out.to_i > 0 ? "#{format(LEFT_OUT_TEXT, @left_out)} #{text}" : text
  end

  # Keeps the options this game's Mod Config has, which are the only ones a notice can name.
  #
  # @param keys [Array<Symbol>] The options.
  # @return [Array<Symbol>] Those of them in a mod's group.
  def self.known_keys(keys)
    known = menu_groups.inject([]) { |all, (_, entries)| all + entries.map { |entry| entry[:key] } }
    keys.select { |key| known.include?(key) }
  end

  # Tells how many options of which mods a world sets.
  #
  # @param keys [Array<Symbol>] The options, each in this game's Mod Config.
  # @return [String] Such as "2 options of Level Cap are".
  def self.options_text(keys)
    keys.size == 1 ? "1 option of #{mods_text(keys)} is" : "#{keys.size} options of #{mods_text(keys)} are"
  end

  # Names the mods whose options some are, as this game's Mod Config groups them.
  #
  # @param keys [Array<Symbol>] The options.
  # @return [String] Such as "Level Cap, Party Sheet and 2 more", "the world's mods" when none is known.
  def self.mods_text(keys)
    names = menu_groups.select { |_, entries| entries.any? { |entry| keys.include?(entry[:key]) } }.map { |name, _| name }
    names.empty? ? "the world's mods" : list_text(names, NAMED_MODS)
  end

  # Names a few things and counts the rest.
  #
  # @param names [Array<String>] The things.
  # @param named [Integer] Most named before the rest is counted.
  # @return [String] Such as "A and B" or "A, B and 3 more".
  def self.list_text(names, named)
    return names.join(" and ") if names.size <= 2 && names.size <= named
    return "#{names[0...-1].join(', ')} and #{names.last}" if names.size <= named

    "#{names.first(named).join(', ')} and #{names.size - named} more"
  end

  # Tells what changed between two of a world's settings: the first few options this game knows by
  # name and value, the rest counted.
  #
  # @param before [Hash] The values before, by the options' keys.
  # @param after [Hash] The values now.
  # @return [String, nil] Such as "Level Cap: On -> Off", nil when nothing changed.
  def self.changes_text(before, after)
    keys = (after.keys + before.keys).uniq.reject { |key| after.key?(key) && before.key?(key) && same_value?(before[key], after[key]) }
    return nil if keys.empty?

    entries = {}
    menu_groups.each { |_, group| group.each { |entry| entries[entry[:key]] ||= entry } }
    known = keys.select { |key| entries[key] }
    named = known.first(NAMED_CHANGES).map do |key|
      from = before.key?(key) ? value_text(key, before[key]) : nil
      to = after.key?(key) ? value_text(key, after[key]) : "no longer shared"
      "#{short_name(entries[key])}: #{from ? "#{from} -> " : ''}#{to}"
    end
    return "#{keys.size} option#{keys.size == 1 ? '' : 's'}" if named.empty?

    rest = keys.size - named.size
    rest > 0 ? "#{named.join(', ')} and #{rest} more" : named.join(", ")
  end

  # Writes a value as Mod Config shows it.
  #
  # @param key [Symbol] The option.
  # @param value [Object] The value.
  # @return [String] The name Mod Config gives it, else the value.
  def self.value_text(key, value)
    texts = NWConst::Config.const_defined?(:DATA_TEXT) ? NWConst::Config::DATA_TEXT[key] : nil
    named = texts && texts[value]
    return named[:name].to_s if named && named[:name]

    value.is_a?(Float) ? format("%.2f", value) : value.to_s
  rescue
    value.to_s
  end

  # Shows a message in the notification box, broken into lines that fit it.
  #
  # @param text [String] The message.
  def self.notify(text)
    log("told the player: #{text}")
    return unless defined?(MGQ_MpNotices)

    NOTICE_LINES.times { |index| MGQ_MpNotices.drop([NOTICE_KEY, index], "a newer one replaces it") }
    lines = notice_lines(text)
    (lines.size - 1).downto(0) { |index| MGQ_MpNotices.message([NOTICE_KEY, index], lines[index], NOTICE_FRAMES) }
  end

  # Breaks a message into lines of the notification box, at most NOTICE_LINES of them.
  #
  # @param text [String] The message.
  # @return [Array<String>] The lines, the last one cut short when the message is longer.
  def self.notice_lines(text)
    lines = [""]
    text.split(" ").each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      if candidate.size <= NOTICE_LINE_CHARS || lines.last.empty?
        lines[-1] = candidate
      else
        lines.push(word)
      end
    end
    return lines if lines.size <= NOTICE_LINES

    kept = lines.first(NOTICE_LINES)
    kept[-1] = "#{kept[-1][0, NOTICE_LINE_CHARS - 3]}..."
    kept
  end

  # What the world screen's details say about a world's mod settings.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @param me [String] The player's id.
  # @return [String] Such as "Mod settings: shared by Creator (Level Cap)", naming the mods whose
  #   options the settings hold as this game's Mod Config groups them.
  def self.details_text(listed, me)
    return "Mod settings: each player's own" unless shared?(listed.settings)

    who = listed.creator_id == me ? "you" : MGQ_Multiplayer.clean(listed.creator_name)
    keys = settings_from(listed.settings).keys
    return "Mod settings: shared by #{who} (none set yet)" if keys.empty?

    known = known_keys(keys)
    what = known.empty? ? "#{keys.size} option#{keys.size == 1 ? '' : 's'} of mods you lack" : mods_text(known)
    "Mod settings: shared by #{who} (#{what})"
  end

  # Follows the settings on their way and the options screen. Called every frame of every scene.
  def self.tick
    @frames = @frames.to_i + 1
    follow_send if @sending
    pump if @wanted && !@sending
    watch_options
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Sends the creator's changed options once they leave the options screen.
  def self.watch_options
    in_options = defined?(Scene_Config) && SceneManager.scene.is_a?(Scene_Config) ? true : false
    left = @in_options && !in_options
    @in_options = in_options
    sync(:options) if left
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # As the title screen starts, Mod Config Remake no longer shows a world's settings.
  MGQ_MpHooks.before(Scene_Title, :start, "world_mods") { MGQ_MpWorldMods.on_title_start }

  # The title screen writes the options dump for the World Admin tool, and opens the world screen to
  # enter a world again after a restart for its mods.
  MGQ_MpHooks.after(Scene_Title, :update, "world_mods") { MGQ_MpWorldMods.on_title_update(self) }

  # Every scene follows the settings on their way, the options screen above all.
  MGQ_MpHooks.after(Scene_Base, :update, "world_mods") { MGQ_MpWorldMods.tick }
rescue => e
  MGQ_MpWorldMods.log("title hooks FAILED: #{e.class}: #{e.message}")
end

# What the world's shared settings take part in of the world, through overworld_sync.rbx.

begin
  if defined?(MGQ_MpOverworldSync)
    MGQ_MpOverworldSync.route(MGQ_MpWorldMods::LIVE_FIELD) { |peer, message| MGQ_MpWorldMods.take_live(peer, message) }
    MGQ_MpOverworldSync.on_observe { |peer| MGQ_MpWorldMods.on_observe(peer) }
    MGQ_MpOverworldSync.on_leave { |peer| MGQ_MpWorldMods.on_leave(peer) }
    MGQ_MpOverworldSync.state_fields { MGQ_MpWorldMods.state_fields }
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
