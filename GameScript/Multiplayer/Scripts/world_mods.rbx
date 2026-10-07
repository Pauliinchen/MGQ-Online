#----------------------------------------------------------------
#  world_mods.rbx
#
#  Changelog:
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
# The creator's settings come from the options each mod offers in Mod Config Remake, which the
# game keeps in each save: a world has saves of its own, so the player's own saves keep their own
# settings, and Mod Config Remake shows the world's as set by the world. Mods build those options
# as they load, so an admin's game reads them for the catalog, which the World Admin tool lists.
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

  # The button in Mod Config that makes the creator's options the world's settings.
  SHARE_BUTTON = :mgq_mp_world_settings

  # The kind of directory action that sends them.
  SHARE_ACTION = "settings"

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
  # @param world_id [String] The world to enter again.
  # @return [Boolean] Whether the game closes now to start again; false when it could not, and stays open.
  def self.restart(world_id)
    MGQ_Multiplayer::Player.store(REJOIN_SETTING, world_id)
    if MGQ_Multiplayer::Link.function('mp_restart_game').call == 1
      log("starting the game again, to enter world #{MGQ_MpWorld.short(world_id)} once it is back")
      return true
    end

    MGQ_Multiplayer::Player.store(REJOIN_SETTING, "")
    log("the game could not start itself again, so world #{MGQ_MpWorld.short(world_id)} is not entered on its own")
    false
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

  # Opens the world screen to enter a world again after a restart. Called by the title screen
  # every frame.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
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

  # Settings.

  # Writes the creator's settings of the options the world's mods offer in Mod Config Remake, the
  # required ones and the listed ones alike, leaving out key bindings, buttons and options marked
  # personal.
  #
  # @param mods [String] The mods as the creator wrote them.
  # @return [Array(String, Array<Symbol>)] "key=type:value" pairs separated by semicolons, at most
  #   MAX_SETTINGS_CHARS of them; and the options left out since they did not fit.
  def self.settings_of(mods)
    return ["", []] unless defined?(NWConst::Config::MOD_CONTENTS) && $game_system

    wanted = MGQ_MpWorld.mods_of(mods).map { |name| MGQ_MpWorld.mod_key(name) }
    pairs = world_options(wanted).map { |key| (encoded = encode(option_value(key))) && [key, "#{key}=#{encoded}"] }.compact
    text, left_out = fit_settings(pairs)
    log("read #{pairs.size - left_out.size} mod setting(s) of #{wanted.join(', ')} for the world: #{text}")
    log("left out #{left_out.size} mod setting(s) past #{MAX_SETTINGS_CHARS} characters: #{left_out.join(', ')}") unless left_out.empty?
    [text, left_out]
  rescue => e
    log("reading the mod settings failed: #{e.class}: #{e.message}")
    ["", []]
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

  # Lists the options of some mods that a world may set: those with values, not key bindings,
  # and not marked personal.
  #
  # @param keys [Array<String>] The mods' keys.
  # @return [Array<Symbol>] The options' keys.
  def self.world_options(keys)
    world_entries(keys).map { |entry| entry[:key] }
  end

  # Finds the Mod Config entries of some mods that a world may set. An entry without "[Mod Name]"
  # in front belongs to the one above it.
  #
  # @param keys [Array<String>] The mods' keys.
  # @return [Array<Hash>] The entries, in the menu's order.
  def self.world_entries(keys)
    group = nil
    NWConst::Config::MOD_CONTENTS.select do |entry|
      name = entry[:name].to_s
      if name =~ /\A\s*\[([^\]]+)\]/
        group = MGQ_MpWorld.mod_key($1)
      elsif name !~ /\A(\s|->)/
        group = nil
      end

      group && keys.include?(group) && entry[:sub] && !entry[:keybind] && !entry[:personal] && entry[:key]
    end
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

    name = entry[:name].to_s.sub(/\A\s*\[[^\]]+\]\s*/, "").sub(/\A[\s\->]+/, "")
    choices = values.map { |value| type_of(value) && [value, (texts[value] && texts[value][:name]) || value] }.compact
    ([key, name, type, default] + choices.flatten).map { |field| field.to_s.gsub(/[\t\r\n]/, " ") }.join("\t")
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
  # @return [Hash] The values by the options' keys.
  def self.settings_from(text)
    text.to_s.split(";").each_with_object({}) do |pair, values|
      key, encoded = pair.split("=", 2)
      readable, value = decode(encoded)
      values[key.to_sym] = value if key && !key.empty? && readable
    end
  end

  # Notes whether the world being entered is the player's own, whose settings they may set.
  #
  # @param world [Array(String, String), nil] The world's id and mods, nil for another's world.
  def self.own_world(world)
    @own = world
    log("entering the player's own world #{MGQ_MpWorld.short(world[0])}: they may set its mod settings") if world
  end

  # Tells whether the player plays in a world they created.
  #
  # @return [Boolean] Whether they do.
  def self.own_world?
    MGQ_MpWorld.open? && @own ? true : false
  end

  # Makes the creator's options of the world's mods its settings, which every player gets
  # the next time they load a save in it. Called by the button in Mod Config.
  #
  # @param window [Window_ModConfig] The menu's window, whose help line tells how it went.
  def self.share(window)
    unless own_world?
      log("not sending the world's mod settings: the player is not in a world they created")
      return Sound.play_buzzer
    end

    id, mods = @own
    text, left_out = settings_of(mods)

    if @sharing || !MGQ_MpWorld::Directory.set_settings(id, text)
      log("not sending the world's mod settings: #{@sharing ? 'the last ones are still on their way' : 'the request could not start'}")
      Sound.play_buzzer
      window.help_window.set_text("Another request is still running. Try again in a moment.") if window.help_window
      return
    end

    @sharing = true
    @left_out = left_out.size
    @settings = settings_from(text)
    window.help_window.set_text("Saving your settings for the world . . .#{left_out_text}") if window.help_window
    log("sending #{@settings.size} mod setting(s) as the world's")
  rescue => e
    log("sending the world's mod settings failed: #{e.class}: #{e.message}")
  end

  # Tells how sending the settings went once the relay answered. Called every frame of every scene.
  def self.follow_share
    return unless @sharing

    action = MGQ_MpWorld::Directory.action
    return if action["state"] == "busy" || action["kind"] != SHARE_ACTION

    @sharing = false
    MGQ_MpWorld::Directory.clear
    text = action["state"] == "done" ? "The world's mod settings were saved. Players get them the next time they load.#{left_out_text}" : "The world's mod settings could not be saved: #{action['error']}"
    MGQ_MpNotices.message(SHARE_ACTION, text) if defined?(MGQ_MpNotices)
    log(text)
  rescue => e
    @sharing = false
    log("following the world's mod settings failed: #{e.class}: #{e.message}")
  end

  # Tells the creator how many options did not fit into the world's settings, if any.
  #
  # @return [String] The sentence with a space in front, "" when every option fit.
  def self.left_out_text
    return "" unless @left_out && @left_out > 0

    " #{@left_out} option(s) did not fit into the world's #{MAX_SETTINGS_CHARS} characters and were left out."
  end

  # Adds the button to Mod Config Remake, which presses it through the handler of its key.
  def self.register
    return unless defined?(ModConfigRemake) && defined?(Window_ModConfig) && defined?(NWConst::Config::MOD_CONTENTS)

    NWConst::Config::MOD_CONTENTS.insert(-2, :key => SHARE_BUTTON, :name => "[Monster Girl Quest! Online] Use My Settings for This World", :sub => false,
                                             :help => "Makes your options of the mods this world names its settings for every player, who get them the next time they load. Only for the world's creator, while playing in it.",
                                             :enable => lambda { MGQ_MpWorldMods.own_world? })
  end

  # Notes the settings of the world being entered, which apply once its game is loaded or started.
  #
  # @param text [String, nil] The world's settings.
  def self.use(text)
    @settings = settings_from(text)
    log("the world sets #{@settings.size} mod setting(s)#{@settings.empty? ? '' : ': ' + settings_text(@settings)}")
  end

  # Writes settings for the log.
  #
  # @param settings [Hash] The values by the options' keys.
  # @return [String] Such as "lv_cap=true, rate=2".
  def self.settings_text(settings)
    settings.map { |key, value| "#{key}=#{value.inspect}" }.join(", ")
  end

  # Writes the world's settings into the game's options and has Mod Config Remake show them as
  # set by the world. Called once a save is loaded or a new game started in a world.
  def self.apply
    return unless MGQ_MpWorld.open? && @settings && $game_system

    changed = @settings.select { |key, value| $game_system.conf[key] != value }
    before = changed.map { |key, value| "#{key} #{$game_system.conf[key].inspect} -> #{value.inspect}" }
    @settings.each { |key, value| $game_system.conf[key] = value }
    # The creator changes them in Mod Config, then makes them the world's with the button.
    lock(own_world? ? [] : @settings.keys)
    log("applied #{@settings.size} mod setting(s) of the world, #{changed.size} changed#{before.empty? ? '' : ': ' + before.join(', ')}; #{own_world? ? 'left unlocked for the creator' : 'locked in Mod Config'}") unless @settings.empty?
  rescue => e
    log("applying the world's mod settings failed: #{e.class}: #{e.message}")
  end

  # Tells Mod Config Remake which options the world sets, if it can show that.
  #
  # @param keys [Array<Symbol>] The options, none outside a world.
  def self.lock(keys)
    ModConfigRemake.world_keys = keys if defined?(ModConfigRemake) && ModConfigRemake.respond_to?(:world_keys=)
  end

  # Lets the options be changed again once the game went back to the title screen.
  def self.on_title_start
    lock([])
    @own = nil
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # As the title screen starts, Mod Config Remake no longer shows a world's settings.
  MGQ_MpHooks.before(Scene_Title, :start, "world_mods") { MGQ_MpWorldMods.on_title_start }

  # The title screen opens the world screen to enter a world again after a restart for its mods.
  MGQ_MpHooks.after(Scene_Title, :update, "world_mods") { MGQ_MpWorldMods.on_title_update(self) }

  # Every scene hears how sending the world's settings went, the options screen above all.
  MGQ_MpHooks.after(Scene_Base, :update, "world_mods") { MGQ_MpWorldMods.follow_share }
rescue => e
  MGQ_MpWorldMods.log("title hooks FAILED: #{e.class}: #{e.message}")
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

begin
  # The button of the world's creator in Mod Config Remake.
  if defined?(Window_ModConfig)
    MGQ_MpWorldMods.register
    MGQ_MpHooks.after(Window_ModConfig, :initialize, "world_mods") do
      set_handler(MGQ_MpWorldMods::SHARE_BUTTON, lambda { MGQ_MpWorldMods.share(self) })
    end
  end
rescue => e
  MGQ_MpWorldMods.log("Mod Config button FAILED: #{e.class}: #{e.message}")
end
