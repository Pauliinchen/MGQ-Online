#----------------------------------------------------------------
#  world_mods.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Applied the world's mod settings from load_game_without_rescue, which the newest translation's load_game still calls
#                            - Checked a link to a zip of a release file by file, like an upload
#                            - Created
#
#----------------------------------------------------------------

# A world's mods: the ones its creator marked as required, which every game that enters must have
# in the same version, and the creator's settings of them, which hold while the player is in the
# world.
#
# The relay's mod catalog, which only its admins fill, names the current version of each mod it
# knows and the hashes of its files. A game whose copy is missing or differs cannot enter, and may
# download the world's version, checked file by file against the catalog, then start again and
# enter the world. A required mod outside the catalog is checked against the hash of the creator's
# copy, which the creator's game sent with the world; that one the player gets from its author.
#
# The creator's settings come from the options each mod offers in Mod Config Remake, which the
# game keeps in each save: a world has saves of its own, so the player's own saves keep their own
# settings, and Mod Config Remake shows the world's as set by the world.
#
# world_screen.rbx, which loads later, checks and installs from the world screen. It must never
# interrupt the game, so every entry point rescues.
module MGQ_MpWorldMods
  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "world mods"

  # Bytes the DLL may write the catalog into at first. A larger catalog asks for a larger buffer.
  CATALOG_SIZE = 65_536

  # Seconds between two readings of the catalog.
  CATALOG_SECONDS = 1.0

  # Bytes of a file's hash and its terminating zero.
  HASH_SIZE = 65

  # The setting in Player.ini that names the world to enter again once the game started anew.
  REJOIN_SETTING = "rejoin"

  # The kinds of mods that come as a zip whose files go to their paths inside Patch.
  ZIP_KINDS = %w(upload zip)

  # A mod of the catalog.
  #
  # @!attribute key [String] Its key, as MGQ_MpWorld.mod_key makes it.
  # @!attribute name [String] Its name.
  # @!attribute kind [String] "link" for a script the relay follows on GitHub, "zip" for a zip of a release there, "upload" for a mod of several files an admin uploaded.
  # @!attribute version [String] Its current version.
  # @!attribute files [Hash] Its current files' hashes, a script's by its name, a zip's or an upload's by each path inside Patch.
  # @!attribute versions [Array<Array>] Each version the relay saw and its files' hashes, newest first.
  Mod = Struct.new(:key, :name, :kind, :version, :files, :versions)

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
    @catalog = state["state"] == "ready" ? parse(state[:payload].to_s) : nil
  rescue => e
    log_once(:catalog, "reading the mod catalog failed: #{e.class}: #{e.message}")
    nil
  end

  # Reads the catalog's lines.
  #
  # @param text [String] One line per mod and version, see WorldDirectory.DescribeMods in the DLL.
  # @return [Array<Mod>] The mods.
  def self.parse(text)
    mods = []

    text.split("\n").each do |line|
      fields = line.split("\t", -1)

      case fields[0]
      when "mod"
        mods.push(Mod.new(fields[1], fields[2].to_s, fields[3].to_s, fields[4].to_s, files_of(fields[5..-1]), []))
      when "old"
        mod = mods.find { |known| known.key == fields[1] }
        mod.versions.push([fields[2].to_s, files_of(fields[3..-1])]) if mod
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
    length = MGQ_Multiplayer::Link.function('mp_mod_hash', 'ppl').call(path + "\0", buffer, buffer.size)
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

  # Writes the creator's hashes of the required mods outside the catalog, for a world being made
  # or changed. A mod the creator's game lacks is left out, so it is only checked for being installed.
  #
  # @param mods [String] The mods as the creator wrote them.
  # @return [String] "name=hash" pairs separated by semicolons.
  def self.creator_hashes(mods)
    known = catalog
    MGQ_MpWorld.required_mods(mods).map do |name|
      next if mod_named(name, known) || name =~ /[=;]/

      path = MGQ_MpWorld.installed_path(name)
      hash = path && hash_of(path)
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
    "#{world} uses other versions of these mods: #{names.join(', ')}.#{action}"
  end

  # Installs the world's versions of mods from the catalog. The DLL checks every file first.
  #
  # @param rows [Array<Row>] The mods, each downloadable.
  # @return [Boolean] Whether the installation started.
  def self.install(rows)
    lines = rows.map { |row| "#{row.mod.key}\t#{row.target}" }.join("\n")
    MGQ_Multiplayer::Link.function('mp_mods_install', 'p').call(lines + "\0") == 1
  end

  # Starts the game again so the installed mods load, and enters the world once it is back.
  #
  # @param world_id [String] The world to enter again.
  # @return [Boolean] Whether the game closes now to start again; false when it could not, and stays open.
  def self.restart(world_id)
    MGQ_Multiplayer::Player.store(REJOIN_SETTING, world_id)
    return true if MGQ_Multiplayer::Link.function('mp_restart_game', 'v').call == 1

    MGQ_Multiplayer::Player.store(REJOIN_SETTING, "")
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
    return if @rejoining || MGQ_MpGame.call(scene, :scene_changing?)

    id = take_rejoin
    return unless id && MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated?

    @rejoining = id
    log("entering world #{id} again after the restart")
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

  # Writes the creator's settings of the options the required mods offer in Mod Config Remake,
  # leaving out key bindings, buttons and options marked personal.
  #
  # @param mods [String] The mods as the creator wrote them.
  # @return [String] "key=type:value" pairs separated by semicolons.
  def self.settings_of(mods)
    return "" unless defined?(NWConst::Config::MOD_CONTENTS) && $game_system

    wanted = MGQ_MpWorld.required_mods(mods).map { |name| MGQ_MpWorld.mod_key(name) }
    world_options(wanted).map { |key| (encoded = encode(option_value(key))) && "#{key}=#{encoded}" }.compact.join(";")
  rescue => e
    log("reading the mod settings failed: #{e.class}: #{e.message}")
    ""
  end

  # Lists the options of some mods that a world may set: those with values, not key bindings,
  # and not marked personal. An option without "[Mod Name]" in front belongs to the one above it.
  #
  # @param keys [Array<String>] The mods' keys.
  # @return [Array<Symbol>] The options' keys.
  def self.world_options(keys)
    group = nil
    NWConst::Config::MOD_CONTENTS.map do |entry|
      name = entry[:name].to_s
      if name =~ /\A\s*\[([^\]]+)\]/
        group = MGQ_MpWorld.mod_key($1)
      elsif name !~ /\A(\s|->)/
        group = nil
      end

      entry[:key] if group && keys.include?(group) && entry[:sub] && !entry[:keybind] && !entry[:personal] && entry[:key]
    end.compact
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
    # Ruby 1.9's whole numbers are Fixnum or Bignum, which case finds as Integer.
    type = case value
           when Integer then "i"
           when Float then "f"
           when true, false then "b"
           when Symbol then "y"
           when String then "s"
           end
    type && "#{type}:#{value.to_s.gsub('%', '%25').gsub(';', '%3B').gsub('=', '%3D')}"
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
    when "f" then raw =~ /\A-?\d+(\.\d+)?(e-?\d+)?\z/i ? [true, raw.to_f] : [false, nil]
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

  # Notes the settings of the world being entered, which apply once its game is loaded or started.
  #
  # @param text [String, nil] The world's settings.
  def self.use(text)
    @settings = settings_from(text)
  end

  # Writes the world's settings into the game's options and has Mod Config Remake show them as
  # set by the world. Called once a save is loaded or a new game started in a world.
  def self.apply
    return unless MGQ_MpWorld.open? && @settings && $game_system

    @settings.each { |key, value| $game_system.conf[key] = value }
    lock(@settings.keys)
    log("applied #{@settings.size} mod setting(s) of the world") unless @settings.empty?
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
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # As the title screen starts, Mod Config Remake no longer shows a world's settings.
  MGQ_MpHooks.before(Scene_Title, :start, "world_mods") { MGQ_MpWorldMods.on_title_start }

  # The title screen opens the world screen to enter a world again after a restart for its mods.
  MGQ_MpHooks.after(Scene_Title, :update, "world_mods") { MGQ_MpWorldMods.on_title_update(self) }
rescue => e
  MGQ_MpWorldMods.log("title hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.

begin
  # A save loaded or a new game started in a world takes the world's mod settings. The newest
  # translation's plugins load after the Patch folder and replace load_game, which still calls
  # load_game_without_rescue.
  MGQ_MpHooks.around(DataManager.singleton_class, :load_game_without_rescue) do |_manager, _args, original|
    loaded = original.call
    MGQ_MpWorldMods.apply if loaded
    loaded
  end

  MGQ_MpHooks.around(DataManager.singleton_class, :setup_new_game) do |_manager, _args, original|
    result = original.call
    MGQ_MpWorldMods.apply
    result
  end
rescue => e
  MGQ_MpWorldMods.log("save hooks FAILED: #{e.class}: #{e.message}")
end
