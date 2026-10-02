#----------------------------------------------------------------
#  mp_world.rbx
#
#  Changelog:
#      Paulinchen  2026-10-02: Offered to copy a world's latest save into the player's own game
#                            - Made worlds without a password, which their players enter without being asked for one
#                            - Showed the featured worlds, which the relay's admins make, in gold after the favourites
#                            - Followed the title screen's start and update through mp_hooks.rbx
#                            - Put the Save folder back in one place as a world closes
#                            - Let the creator tick Players choose, after which each new player starts at the beginning, from one of their own saves or from the starting save
#      Paulinchen  2026-10-01: Said that the relay's admins see hidden worlds too
#      Paulinchen  2026-09-30: Let the relay's admins see every world, hidden ones too, and delete any
#                            - Moved into Patch/Multiplayer/Scripts as mp_world.rbx, which Multiplayer.rb loads, with the worlds in Patch/Multiplayer/Worlds
#                            - Named the mod Monster Girl Quest! Online in the update notice
#                            - Greyed out the title command and showed a notice once a newer release is out
#                            - Let the creator pick one of their saves as the starting save of a new world, which new players fetch before entering it
#                            - Made and joined worlds through forms at the right of the world screen, typed in place, and made hidden worlds, joined by their id
#      Paulinchen  2026-09-29: Listed the relay's worlds with their players, favourites first, entered with a password once and typed names on the keyboard
#                            - Let the creator delete a world or remove a player, and connected to a world while it is open
#                            - Created
#
#----------------------------------------------------------------

# Worlds: lasting places several players play in together, entered through Multiplayer on the
# title screen. The relay's world directory lists every public world with its players, and hidden
# ones only for their players and the relay's admins; others join a hidden world by its id. An
# admin may delete any world, and the admins' featured worlds show in gold. A world's password, if
# it has one, is asked once, after which this game remembers the world. Each world keeps its own saves and its
# own system save (Library, medals, system switches, affection) in Patch/Multiplayer/Worlds/<id>, so
# playing in a world never touches the player's own saves. A new world's players start at the
# beginning, from one of its creator's saves, or where each of them chooses (mp_save_distribution.rbx).
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorld
  # Turns worlds off without uninstalling them.
  ENABLED = true

  # The title screen's command that opens the world screen.
  COMMAND_NAME = "Multiplayer"

  # Folder of the worlds on this PC, inside the mod folder.
  WORLDS_DIR = "Patch/Multiplayer/Worlds"

  # File of the worlds the player marked as favourites, inside the mod folder.
  FAVOURITES_FILE = "Favourites.ini"

  # Players a new world seats at most unless the player chooses otherwise.
  DEFAULT_SEATS = 4

  # Fewest players a world seats.
  MIN_SEATS = 2

  # Most players a world seats.
  MAX_SEATS = 32

  # Longest name of a player or a world.
  MAX_NAME_CHARS = 16

  # Longest password.
  MAX_PASSWORD_CHARS = 20

  # A world's id, which joins a hidden world.
  WORLD_ID = /\A[0-9a-f]{32}\z/

  # Colour of the featured worlds, which the relay's admins make.
  FEATURED_COLOR = Color.new(255, 200, 64)

  # The buttons whose press, in a frame no key went down, tells a gamepad from the keyboard.
  #
  # Directions count by their first frame only, since an arrow key held down reports its
  # direction in later frames too.
  GAMEPAD_BUTTONS = [:C, :B, :A, :UP, :DOWN, :LEFT, :RIGHT]

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Title.method_defined?(:mgq_mp_world_terminate)
  end

  # Tells whether worlds can be used.
  #
  # @return [Boolean] Whether worlds are on, the mod's DLL is installed, and no newer
  #   release is out.
  def self.available?
    ENABLED && MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated?
  end

  # Writes a line to the mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("world: #{message}")
  rescue
  end

  # Reports whether a world is open, which the game's saves then belong to.
  #
  # @return [Boolean] Whether a world is open.
  def self.open?
    !@world.nil?
  end

  # The open world.
  #
  # @return [World, nil] The world, nil while none is open.
  def self.world
    @world
  end

  # What the text screen handed back: what the text was for, and the text, nil when the player left it.
  #
  # @return [Array, nil] [kind, text or nil], nil while none waits.
  def self.take_text_result
    result = @text_result
    @text_result = nil
    result
  end

  # Keeps what the text screen hands back.
  #
  # @param result [Array] [kind, text or nil].
  def self.text_result=(result)
    @text_result = result
  end

  # Reports whether a button or direction was pressed this frame, which only a gamepad does in a
  # frame no key went down.
  #
  # @return [Boolean] Whether one was.
  def self.gamepad_pressed?
    GAMEPAD_BUTTONS.any? { |button| Input.trigger?(button) }
  end

  # Enters a world from the world screen: its latest save when it has one, a new game otherwise,
  # which the title screen starts once the world screen closed.
  #
  # @param world [World] The world.
  # @param scene [Scene_MpWorlds] The world screen.
  # @return [String, nil] Why the world could not be entered, nil when it was.
  def self.start(world, scene)
    enter(world)
    index = world.latest_save

    unless index
      @pending = :new_game
      scene.return_scene
      return nil
    end

    unless DataManager.load_game(index)
      leave
      return "The latest save of #{world.name} could not be loaded."
    end

    log("loaded save #{index} of world #{world.id}")
    # Scene_Load finishes the game's own loads, so the map starts exactly as after Continue.
    Scene_Load.new.on_load_success
    nil
  rescue => e
    leave
    log("could not enter a world: #{e.class}: #{e.message}")
    "The world could not be entered."
  end

  # Opens a world: from now on the game's saves and system save are the world's, and the game
  # holds a seat in the world's room.
  #
  # @param world [World] The world.
  def self.enter(world)
    leave
    Dir.mkdir(world.save_folder) unless File.directory?(world.save_folder)
    System.enter(world.save_folder)
    @world = world
    world.played!
    Link.open(world.code)
    log("entered world #{world.id}")
  end

  # Closes the open world, leaving its room and putting the player's own system save back.
  def self.leave
    return unless @world

    Link.close
    System.leave
    log("left world #{@world.id}")
    @world = nil
  rescue => e
    @world = nil
    log("could not leave the world cleanly: #{e.class}: #{e.message}")
  end

  # Closes the open world once the game went back to the title screen, unless the world screen
  # sent it there to start a new game in the world. Called as the title screen starts.
  def self.on_title_start
    leave unless @pending
  end

  # Starts a new game in the world the world screen opened. Called by the title screen every
  # frame while nothing else runs.
  #
  # The title screen's own command starts it, so everything the game and other mods do for a
  # new game happens as usual.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    return unless @pending == :new_game

    @pending = nil
    log("new game in world #{@world.id}") if @world
    scene.command_new_game
  rescue => e
    @pending = nil
    leave
    log("could not start a new game in a world: #{e.class}: #{e.message}")
  end

  # Adds the world screen's command to the title screen, below Continue: greyed out, with
  # UpdateNotice saying why, once a newer release is out.
  #
  # @param window [Window_TitleCommand] The title screen's commands.
  def self.add_title_command(window)
    return unless MGQ_Multiplayer.available?

    list = window.instance_variable_get(:@list)
    entry = { :name => COMMAND_NAME, :symbol => :mgq_mp_world, :enabled => !MGQ_Multiplayer.outdated?, :ext => nil }
    continue_at = list.index { |command| command[:symbol] == :continue }
    continue_at ? list.insert(continue_at + 1, entry) : list.push(entry)
  rescue => e
    log("title command failed: #{e.class}: #{e.message}")
  end

  # Two lines on the title screen, below Discord's own update notice if it shows one too, once a
  # newer release of the mod is out.
  module UpdateNotice
    # What the notice says, the newer version filled in.
    LINES = [
      "Monster Girl Quest! Online %s is out.",
      "Close the game and run Patch\\Multiplayer\\Update.bat to update.",
    ]

    # Height of a line, which the font size follows.
    LINE_HEIGHT = 20

    # Where the notice starts: below the translation's version and Discord's own notice, which
    # takes up to two lines from TOP 24.
    TOP = 64

    # Gap to the left and right edges of the screen.
    MARGIN = 4

    # Layer of the title screen's foreground, which the notice belongs to.
    Z = 100

    # Shows the notice on the title screen once a newer release is out. Called every update.
    def self.refresh
      return if @sprite || !SceneManager.scene.is_a?(Scene_Title)
      return unless MGQ_Multiplayer.available? && (version = MGQ_Multiplayer.newer_version)

      show(version)
    end

    # Takes the notice off the screen. Called when the title screen ends.
    def self.hide
      return unless @sprite

      @sprite.bitmap.dispose
      @sprite.dispose
      @sprite = nil
    end

    # Draws the notice.
    #
    # @param version [String] The newer release's version.
    def self.show(version)
      @sprite = Sprite.new
      @sprite.bitmap = Bitmap.new(Graphics.width, LINE_HEIGHT * LINES.size)
      @sprite.bitmap.font.size = LINE_HEIGHT
      @sprite.y = TOP
      @sprite.z = Z

      LINES.each_with_index do |line, index|
        @sprite.bitmap.draw_text(MARGIN, index * LINE_HEIGHT, Graphics.width - 2 * MARGIN, LINE_HEIGHT, format(line, version))
      end
    end
  end

  # Builds what the world screen lists: the directory's worlds, and the worlds on this PC the
  # directory no longer has, favourites first, then the featured ones, then those played last,
  # then by name.
  #
  # @param listed [Array<Directory::ListedWorld>] The directory's worlds.
  # @param complete [Boolean] Whether the directory's list arrived, so a world missing from it is gone.
  # @return [Array<Entry>] The entries.
  def self.entries(listed, complete)
    local = World.all
    by_directory_id = {}
    local.each { |world| by_directory_id[world.directory_id] = world if world.directory_id }
    favourites = Favourites.all

    entries = listed.map { |world| Entry.new(world.id, world.name, world, by_directory_id[world.id], favourites.include?(world.id), false) }
    listed_ids = listed.map { |world| world.id }
    local.each do |world|
      next if world.directory_id && listed_ids.include?(world.directory_id)

      entries.push(Entry.new(world.directory_id, world.name, nil, world, favourites.include?(world.directory_id), complete || !world.directory_id))
    end

    entries.sort_by { |entry| [entry.favourite ? 0 : 1, entry.featured? ? 0 : 1, -(entry.local ? entry.local.played_at.to_i : 0), entry.name.downcase] }
  end

  # A world as the world screen lists it: the directory's, this PC's folder of it, or both.
  #
  # @!attribute id [String, nil] The directory's id of the world, nil for a world made before the directory.
  # @!attribute name [String] The world's name.
  # @!attribute listed [Directory::ListedWorld, nil] The world in the directory, nil once its creator deleted it.
  # @!attribute local [World, nil] The world's folder on this PC, nil before the player entered it.
  # @!attribute favourite [Boolean] Whether the player marked it as a favourite.
  # @!attribute gone [Boolean] Whether the directory no longer has it, as opposed to its list not having arrived.
  Entry = Struct.new(:id, :name, :listed, :local, :favourite, :gone) do
    # Tells whether the directory lists the world as one of the relay's own, which an admin made.
    #
    # @return [Boolean] Whether it does.
    def featured?
      !listed.nil? && listed.featured
    end

    # Tells whether the directory lists the world as one without a password.
    #
    # @return [Boolean] Whether it does.
    def open?
      !listed.nil? && listed.open
    end
  end

  # Patch/Multiplayer/Multiplayer.dll's world functions: the folder id of a world code, and the
  # connection to the open world's room.
  module Link
    # Names a world's folder by its code.
    #
    # @param code [String] The world code.
    # @return [String, nil] The folder's id, nil when the text is no world code.
    def self.id_of(code)
      buffer = "\0" * 64
      length = MGQ_Multiplayer::Link.function('mp_world_id', 'ppl').call(code + "\0", buffer, buffer.size)
      length > 0 ? buffer[0, length] : nil
    end

    # Takes a seat in a world's room, again whenever the connection breaks, until the world is closed.
    #
    # @param code [String] The world code.
    def self.open(code)
      MGQ_Multiplayer::Player.share
      MGQ_MpWorld.log("could not open the world's connection") unless MGQ_Multiplayer::Link.function('mp_world_open', 'p').call(code + "\0") == 1
    end

    # Leaves the world's room.
    def self.close
      MGQ_Multiplayer::Link.function('mp_world_close', 'v').call
    end

    # Puts a text on the clipboard.
    #
    # @param text [String] The text.
    # @return [Boolean] Whether the clipboard holds it.
    def self.copy(text)
      MGQ_Multiplayer::Link.function('mp_copy_text', 'p').call(text + "\0") == 1
    end
  end

  # The relay's world directory, through Patch/Multiplayer/Multiplayer.dll: the list of worlds,
  # fetched again whenever asked, and one action at a time.
  module Directory
    # A world as the directory lists it.
    #
    # @!attribute id [String] The world's id.
    # @!attribute seats [Integer] How many players it seats at once.
    # @!attribute online [Integer] How many are in it now.
    # @!attribute creator_id [String] The creator's player id.
    # @!attribute active [Integer] When someone was last in it, in milliseconds since 1970.
    # @!attribute creator_name [String] The creator's name.
    # @!attribute name [String] The world's name.
    # @!attribute start [String] How far it is with its starting save: "none", "pending" or "ready".
    # @!attribute members [Array<Member>] Everyone who ever joined it, those online first.
    # @!attribute hidden [Boolean] Whether the list leaves it out for everyone but its players and the relay's admins.
    # @!attribute choose [Boolean] Whether each new player chooses where to start.
    # @!attribute open [Boolean] Whether it has no password.
    # @!attribute featured [Boolean] Whether it is one of the relay's own worlds, which an admin made.
    ListedWorld = Struct.new(:id, :seats, :online, :creator_id, :active, :creator_name, :name, :start, :members, :hidden, :choose, :open, :featured)

    # A player of a world.
    #
    # @!attribute id [String] The player's id.
    # @!attribute online [Boolean] Whether the player is in the world now.
    # @!attribute name [String] The player's name.
    Member = Struct.new(:id, :online, :name)

    # Bytes the DLL may write the list into at first. A larger list asks for a larger buffer.
    LIST_SIZE = 65_536

    # Fetches the list again.
    def self.refresh
      MGQ_Multiplayer::Link.function('mp_dir_refresh', 'v').call
    end

    # Reads the list as it stands.
    #
    # @return [Array] The state ("idle", "loading", "ready" or "failed"), why it failed, the worlds, and whether the player is one of the relay's admins, who sees every world and may delete any.
    def self.list
      state = MGQ_Multiplayer::Link.parse(MGQ_Multiplayer::Link.read('mp_dir_list', LIST_SIZE))
      worlds = []

      state[:payload].split("\n").each do |line|
        fields = line.split("\t", -1)

        case fields[0]
        when "world"
          worlds.push(ListedWorld.new(fields[1], fields[2].to_i, fields[3].to_i, fields[4], fields[5].to_i, fields[6].to_s, fields[7].to_s, fields[8] || "none", [], fields[9] == "1", fields[10] == "1", fields[11] == "1", fields[12] == "1"))
        when "member"
          worlds.last.members.push(Member.new(fields[1], fields[2] == "1", fields[3].to_s)) if worlds.last
        end
      end

      [state["state"] || "idle", state["error"], worlds, state["admin"] == "1"]
    end

    # Makes a world, locked with its password, with the starting save new players get, if there is one.
    #
    # @param name [String] The world's name.
    # @param password [String] The password, empty for none.
    # @param seats [Integer] How many players it seats at once.
    # @param hidden [Boolean] Whether the list leaves it out for everyone but its players and the relay's admins.
    # @param choose [Boolean] Whether each new player chooses where to start.
    # @param start [String] The starting save's files, see MGQ_MpSaveDistribution.text_of; empty for none.
    # @return [Boolean] Whether the action started.
    def self.create(name, password, seats, hidden, choose, start)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_create', 'pplllp').call(name + "\0", password + "\0", seats, hidden ? 1 : 0, choose ? 1 : 0, start + "\0") == 1
    end

    # Opens a world's lock with its password; the action tells the world's name, its starting save
    # and whether new players choose where to start too, so a hidden world is joined by its id alone.
    #
    # @param id [String] The world's id.
    # @param password [String] The password.
    # @return [Boolean] Whether the action started.
    def self.unlock(id, password)
      MGQ_Multiplayer::Link.function('mp_dir_unlock', 'pp').call(id + "\0", password + "\0") == 1
    end

    # Deletes a world for everyone.
    #
    # @param id [String] The world.
    # @return [Boolean] Whether the action started.
    def self.delete(id)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_delete', 'p').call(id + "\0") == 1
    end

    # Removes a player from a world and keeps them out.
    #
    # @param id [String] The world.
    # @param target [String] The player's id.
    # @return [Boolean] Whether the action started.
    def self.ban(id, target)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_ban', 'pp').call(id + "\0", target + "\0") == 1
    end

    # Reads how the running or last action stands.
    #
    # @return [Hash] "state" ("idle", "busy", "done" or "failed"), and whichever of "kind", "code", "world", "name", "start", "choose" ("1" when new players choose where to start) and "error" apply.
    def self.action
      text = MGQ_Multiplayer::Link.read('mp_dir_action', 1024)
      text.empty? ? { "state" => "idle" } : MGQ_Multiplayer::Link.parse(text)
    end

    # Forgets the last action once its result was taken.
    def self.clear
      MGQ_Multiplayer::Link.function('mp_dir_clear', 'v').call
    end

    # Reads the id everyone sees for the player.
    #
    # @return [String] The id, "" while the player has no name.
    def self.my_id
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.player_id
    end
  end

  # The worlds the player marked as favourites, in Patch/Multiplayer/Favourites.ini.
  module Favourites
    # Lists the favourites.
    #
    # @return [Array<String>] The directory ids of the favourite worlds.
    def self.all
      MGQ_Multiplayer::Ini.read(MGQ_Multiplayer.path(FAVOURITES_FILE)).keys
    end

    # Marks a world as a favourite, or no longer.
    #
    # @param id [String] The world's directory id.
    # @return [Boolean] Whether it is a favourite now.
    def self.toggle(id)
      values = MGQ_Multiplayer::Ini.read(MGQ_Multiplayer.path(FAVOURITES_FILE))
      favourite = !values.key?(id)
      favourite ? values[id] = "1" : values.delete(id)
      MGQ_Multiplayer::Ini.write(MGQ_Multiplayer.path(FAVOURITES_FILE), values)
      favourite
    end
  end

  # A world on this PC: its folder in Patch/Multiplayer/Worlds, named by a hash of its code, with
  # world.ini (name, world code, directory id, when it was made and last played) and the world's
  # Save folder.
  class World
    # The file inside the world's folder that describes it.
    FILE = "world.ini"

    # What a world's folder is named.
    ID = /\A[0-9a-f]{12}\z/

    # Lists the worlds on this PC.
    #
    # @return [Array<World>] The worlds.
    def self.all
      return [] unless File.directory?(WORLDS_DIR)

      Dir.entries(WORLDS_DIR).select { |entry| entry =~ ID }.map { |id| read(id) }.compact
    rescue => e
      MGQ_MpWorld.log("could not list the worlds: #{e.class}: #{e.message}")
      []
    end

    # Reads a world.
    #
    # @param id [String] The folder's id.
    # @return [World, nil] The world, nil when its folder holds none.
    def self.read(id)
      values = MGQ_Multiplayer::Ini.read("#{folder_of(id)}/#{FILE}")
      code = values["code"]
      code && Link.id_of(code) == id ? new(id, values) : nil
    end

    # Makes a world's folder, or finds the one there is, and describes the world in it.
    #
    # @param code [String] The world code.
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @return [World, nil] The world, nil when the text is no world code or the folder could not be made.
    def self.found(code, name, directory_id)
      id = Link.id_of(code)
      return nil unless id

      [WORLDS_DIR, folder_of(id)].each { |dir| Dir.mkdir(dir) unless File.directory?(dir) }
      world = read(id) || new(id, "code" => code, "created" => Time.now.to_i)
      world.describe(name, directory_id)
      world.write ? world : nil
    rescue => e
      MGQ_MpWorld.log("could not make a world's folder: #{e.class}: #{e.message}")
      nil
    end

    # Builds the folder of a world.
    #
    # @param id [String] The folder's id.
    # @return [String] The folder, relative to the game's folder.
    def self.folder_of(id)
      "#{WORLDS_DIR}/#{id}"
    end

    # The folder's id.
    attr_reader :id

    # The world's name.
    attr_reader :name

    # The world code, which lets its holder in.
    attr_reader :code

    # The world's id in the directory, nil for a world made before the directory.
    attr_reader :directory_id

    # When the world was played last.
    attr_reader :played_at

    # Creates a world from what its world.ini says.
    #
    # @param id [String] The folder's id.
    # @param values [Hash] The values of its world.ini.
    def initialize(id, values)
      @id = id
      @name = values["name"].to_s.strip.empty? ? "?" : MGQ_Multiplayer.clean(values["name"])
      @code = values["code"]
      @directory_id = values["world"]
      @created = values["created"].to_i
      @played_at = values["played"] ? Time.at(values["played"].to_i) : nil
    end

    # Takes the world's name and directory id, as the directory says them.
    #
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    def describe(name, directory_id)
      @name = MGQ_Multiplayer.clean(name)
      @directory_id = directory_id
    end

    # The world's folder.
    #
    # @return [String] The folder, relative to the game's folder.
    def folder
      World.folder_of(@id)
    end

    # The folder of the world's saves, which the game's Save folder stands for while it is open.
    #
    # @return [String] The folder, relative to the game's folder.
    def save_folder
      "#{folder}/Save"
    end

    # Notes that the world is played now.
    def played!
      @played_at = Time.now
      write
    end

    # Writes world.ini.
    #
    # @return [Boolean] Whether it was written.
    def write
      values = { "name" => @name, "code" => @code, "created" => @created }
      values["world"] = @directory_id if @directory_id
      values["played"] = @played_at.to_i if @played_at
      MGQ_Multiplayer::Ini.write("#{folder}/#{FILE}", values)
    end

    # Finds the world's latest save, an autosave included.
    #
    # @return [Integer, String, nil] The save's index as DataManager takes it, nil without any save.
    def latest_save
      latest = latest_save_entry
      latest && latest[0]
    end

    # Finds the file of the world's latest save, an autosave included.
    #
    # @return [String, nil] Its path, relative to the game's folder; nil without any save.
    def latest_save_file
      latest = latest_save_entry
      latest && "#{save_folder}/#{latest[1]}"
    end

    # Finds the world's latest save and its file.
    #
    # It looks at the files themselves, since the game only finds a world's saves while the world is open.
    #
    # @return [Array, nil] The save's index as DataManager takes it and its file's name, nil without any save.
    def latest_save_entry
      return nil unless File.directory?(save_folder)

      saves = Dir.entries(save_folder).map do |entry|
        case entry
        when /\ASave(\d{2})\.rvdata2\z/i then [$1.to_i - 1, entry]
        when /\AAutoSave(\d{2})\.rvdata2\z/i then [$1, entry]
        end
      end
      saves.compact.max_by { |_, entry| File.mtime("#{save_folder}/#{entry}") }
    end

    # Deletes the world's folder with everything in it: this game's saves of the world, and that
    # it remembers the world's password.
    #
    # @return [Boolean] Whether it was deleted.
    def delete
      World.remove_tree(folder)
      true
    rescue => e
      MGQ_MpWorld.log("could not delete world #{@id}: #{e.class}: #{e.message}")
      false
    end

    # Deletes a folder with everything in it.
    #
    # @param path [String] The folder.
    def self.remove_tree(path)
      Dir.entries(path).each do |entry|
        next if entry == "." || entry == ".."

        child = "#{path}/#{entry}"
        File.directory?(child) ? remove_tree(child) : File.delete(child)
      end
      Dir.rmdir(path)
    end
  end

  # While a world is open, sends every path below the game's Save folder to the world's instead.
  #
  # The game names its Save folder in many places, its thumbnails and backups included, so the
  # paths are changed where they reach the files rather than where the game builds them.
  module Files
    # A path below the game's Save folder.
    SAVE_PATH = /\ASave(?=[\\\/]|\z)/i

    # The File methods that take paths.
    FILE_METHODS = [:open, :new, :exist?, :exists?, :file?, :directory?, :delete, :unlink, :rename, :mtime, :size, :stat, :read, :binread]

    # The Dir methods that take paths or patterns.
    DIR_METHODS = [:glob, :[], :entries, :foreach, :exist?, :exists?, :mkdir]

    # Sets the folder that stands for the Save folder, or nil for the game's own.
    #
    # @param folder [String, nil] The folder.
    def self.root=(folder)
      @root = folder
    end

    # Runs a block with the paths below the Save folder reaching the game's own Save folder, also
    # while a world is open.
    #
    # @return [Object] What the block returns.
    def self.unmapped
      root = @root
      @root = nil
      yield
    ensure
      @root = root
    end

    # Changes the paths among some arguments that lie below the Save folder.
    #
    # @param args [Array] The arguments.
    # @return [Array] The arguments, those paths moved to the open world's folder.
    def self.mapped(args)
      return args unless @root

      args.map { |arg| arg.is_a?(String) && arg =~ SAVE_PATH ? @root + arg[4..-1] : arg }
    end

    # Wraps the File and Dir methods that take paths.
    def self.install
      redirect(File, FILE_METHODS)
      redirect(Dir, DIR_METHODS)
    end

    # Wraps some class methods so their paths go through mapped.
    #
    # @param owner [Class] File or Dir.
    # @param names [Array<Symbol>] The methods.
    def self.redirect(owner, names)
      names.each do |name|
        next unless owner.respond_to?(name)

        original = :"mgq_mp_world_#{name.to_s.sub('?', '_query').sub('[]', 'index')}"
        next if owner.respond_to?(original)

        owner.singleton_class.send(:alias_method, original, name)
        owner.singleton_class.send(:define_method, name) do |*args, &block|
          send(original, *MGQ_MpWorld::Files.mapped(args), &block)
        end
      end
    end
  end

  # The data all saves share, the system save: the Library, the system switches and the global
  # system, which holds the affection. A world keeps its own.
  module System
    # Writes the player's own system save and loads the world's, making a new one the first time.
    #
    # @param folder [String] The folder of the world's saves.
    def self.enter(folder)
      DataManager.save_system
      @own = [$game_library, $game_system_switches, $game_global_system, DataManager.instance_variable_get(:@system_save_count)]
      Files.root = folder
      $game_library = $game_system_switches = $game_global_system = nil
      DataManager.setup_system
    end

    # Writes the world's system save and puts the player's own back.
    def self.leave
      return unless @own

      DataManager.save_system
      $game_library, $game_system_switches, $game_global_system, count = @own
      DataManager.instance_variable_set(:@system_save_count, count)
      @own = nil
    ensure
      Files.root = nil
    end
  end

  # A form of the world screen: its fields, laid out in rows, and what is filled in.
  class Form
    # A field of a form: a text box (:text, :password, :number or :id), a checkbox (:check), a save
    # to choose (:save) or the button that sends the form (:button).
    class Field
      # What the form keeps the field's value under.
      attr_reader :key

      # What kind of field it is.
      attr_reader :kind

      # What the field is called.
      attr_reader :label

      # The row it is on, 0 for the first below the form's title.
      attr_reader :row

      # :left or :right when it shares its row with another field, nil when it has the row alone.
      attr_reader :side

      # The longest text a text box takes.
      attr_reader :max_chars

      # The characters a text box takes, nil for any.
      attr_reader :allowed

      # The checkbox that must be ticked for the field to be used, nil for none.
      attr_reader :needs

      # What the lines at the top of the world screen say while the cursor is on the field.
      attr_reader :hint

      # Creates a field.
      #
      # @param key [Symbol] What the form keeps its value under.
      # @param kind [Symbol] What kind of field it is.
      # @param label [String] What it is called.
      # @param row [Integer] The row it is on.
      # @param hint [String] What the lines at the top say while the cursor is on it.
      # @param options [Hash] Whichever of :side, :max_chars, :allowed and :needs apply.
      def initialize(key, kind, label, row, hint, options = {})
        @key = key
        @kind = kind
        @label = label
        @row = row
        @hint = hint
        @side = options[:side]
        @max_chars = options[:max_chars]
        @allowed = options[:allowed]
        @needs = options[:needs]
      end

      # Tells whether the field is a text box, typed into.
      #
      # @return [Boolean] Whether it is.
      def typed?
        [:text, :password, :number, :id].include?(@kind)
      end
    end

    # The form of a new world.
    #
    # @return [Form] The form, empty but for the default seats.
    def self.create
      fields = [
        Field.new(:name, :text, "Name", 0, "The name everyone sees in the list.", :max_chars => MAX_NAME_CHARS),
        Field.new(:password, :password, "Password", 1, "Everyone types it once to enter the world. Left empty, anyone may enter without one.", :max_chars => MAX_PASSWORD_CHARS),
        Field.new(:seats, :number, "Max Players", 2, "How many players may be in the world at once, #{MIN_SEATS} to #{MAX_SEATS}. It cannot be changed later.", :max_chars => MAX_SEATS.to_s.size, :allowed => /\A\d\z/),
        Field.new(:hidden, :check, "Hidden", 3, "Ticked, only its players and the relay's admins see it in the list: share its id, and its password if it has one, with those who may join. Otherwise everyone sees it.", :side => :left),
        Field.new(:from_save, :check, "From my save", 3, "Ticked, new players start from one of your saves instead of the opening; with Players choose their start ticked, it is one of their choices. It cannot be changed later.", :side => :right),
        Field.new(:save, :save, "Save", 4, "The save every new player starts from.", :needs => :from_save),
        Field.new(:choose, :check, "Players choose their start", 5, "Ticked, each new player chooses: at the beginning, from one of their own saves, or from your save when From my save is ticked. It cannot be changed later."),
        Field.new(:confirm, :button, "Create the world", 7, "Makes the world and enters it."),
      ]
      new("Create a new world", fields, :name => "", :password => "", :seats => DEFAULT_SEATS.to_s, :hidden => false, :from_save => false, :save => nil, :choose => false)
    end

    # The form that joins a hidden world by its id.
    #
    # @return [Form] The form, empty.
    def self.join
      fields = [
        Field.new(:id, :id, "World id", 0, "The id the world's creator copied for you. Ctrl+V pastes it.", :max_chars => 32, :allowed => /\A[0-9a-f]\z/i),
        Field.new(:password, :password, "Password", 1, "The world's password; left empty for a world without one.", :max_chars => MAX_PASSWORD_CHARS),
        Field.new(:confirm, :button, "Join the world", 3, "Opens the world and enters it."),
      ]
      new("Join a hidden world", fields, :id => "", :password => "")
    end

    # What the form is called.
    attr_reader :title

    # The fields, in the order the cursor visits them.
    attr_reader :fields

    # The key of the text box being typed into, nil while none is.
    attr_accessor :editing

    # Creates a form.
    #
    # @param title [String] What the form is called.
    # @param fields [Array<Field>] The fields.
    # @param values [Hash] What each field holds at first, by key.
    def initialize(title, fields, values)
      @title = title
      @fields = fields
      @values = values
    end

    # Reads what a field holds.
    #
    # @param key [Symbol] The field's key.
    # @return [Object] The value.
    def [](key)
      @values[key]
    end

    # Sets what a field holds.
    #
    # @param key [Symbol] The field's key.
    # @param value [Object] The value.
    def []=(key, value)
      @values[key] = value
    end

    # Tells whether a field can be used, which one whose checkbox is not ticked cannot.
    #
    # @param field [Field] The field.
    # @return [Boolean] Whether it can.
    def enabled?(field)
      field.needs.nil? || @values[field.needs] == true
    end

    # Adds a typed character to a text box, if it takes it.
    #
    # @param field [Field] The text box.
    # @param char [String] The character.
    # @return [Boolean] Whether it was added.
    def add(field, char)
      text = @values[field.key]
      return false if text.size >= field.max_chars || (field.allowed && char !~ field.allowed)

      @values[field.key] = text + char
      true
    end

    # Checks what a text box holds, and tidies it.
    #
    # @param field [Field] The text box.
    # @param text [String] What it holds.
    # @return [Array] The tidied text, and why it is not accepted, nil when it is.
    def check(field, text)
      case field.kind
      when :number
        seats = text =~ /\A\d+\z/ ? text.to_i : nil
        return [text, "#{field.label} must be a number from #{MIN_SEATS} to #{MAX_SEATS}."] unless seats && seats.between?(MIN_SEATS, MAX_SEATS)

        [seats.to_s, nil]
      when :id
        id = text.strip.downcase
        id =~ WORLD_ID ? [id, nil] : [text, "A world id has 32 characters, the digits and a to f."]
      when :password
        # A password keeps its spaces, since the others type it exactly, and may be empty.
        [text, nil]
      else
        tidy = text.strip
        tidy.empty? ? [text, "The #{field.label.downcase} cannot be empty."] : [tidy, nil]
      end
    end

    # Finds the first field that keeps the form from being sent.
    #
    # @return [Array, nil] The field's index and why, nil when the form can be sent.
    def problem
      @fields.each_with_index do |field, index|
        next unless enabled?(field)

        error = field.typed? ? check(field, @values[field.key])[1] : nil
        error ||= "Choose the save its players start from." if field.kind == :save && @values[field.key].nil?
        return [index, error] if error
      end
      nil
    end
  end
end

# The world screen, opened from the title screen: every world of the relay's directory at the left,
# the chosen one's players at the right, and what the player can do with it. Creating a world and
# joining a hidden one are forms that take the right side while the list points at them.
class Scene_MpWorlds < Scene_MenuBase
  # What the screen says while nothing else happened.
  HINT = "Choose a world to enter it, or make a new one."

  # What the screen says while a text box is typed into.
  TYPING_HINT = "Type on the keyboard. Enter keeps it, Esc goes back."

  # Frames between two fetches of the list, ten seconds at 60 frames per second.
  REFRESH_FRAMES = 600

  # Frames between two looks at the list the DLL holds.
  LOOK_FRAMES = 20

  # What the screen says while an action runs, by the action's kind.
  BUSY_TEXTS = {
    "create" => "Making the world . . .",
    "unlock" => "Opening the world . . .",
    "delete" => "Deleting the world . . .",
    "ban" => "Removing the player . . .",
    "start" => "Fetching the starting save . . .",
  }

  # Creates the windows, fetches the list, and takes what the text or save screen handed back.
  #
  # The scene is the same object again when those screens return, so the forms keep what was
  # filled in.
  def start
    super
    @info_window = Window_MpWorldInfo.new
    @list_window = Window_MpWorldList.new(@info_window.height)
    @detail_window = Window_MpWorldDetail.new(@list_window.width, @info_window.height, @list_window.height)
    @form_window = Window_MpWorldForm.new(@detail_window.x, @detail_window.y, @detail_window.width, @detail_window.height)
    @form_window.set_handler(:ok, method(:on_field))
    @form_window.set_handler(:cancel, method(:leave_form))
    @list_window.set_handler(:world, method(:on_world))
    @list_window.set_handler(:new_world, method(:enter_form))
    @list_window.set_handler(:join_hidden, method(:enter_form))
    @list_window.set_handler(:rename, method(:on_rename))
    @list_window.set_handler(:cancel, method(:return_scene))
    @actions_window = Window_MpChoice.new
    [:enter, :favourite, :copy_id, :ban, :delete_world, :export_save, :delete_saves].each { |symbol| @actions_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @actions_window.set_handler(:cancel, method(:back_to_list))
    @members_window = Window_MpChoice.new
    @members_window.set_handler(:member, method(:on_member))
    @members_window.set_handler(:cancel, method(:back_to_list))
    @confirm_window = Window_MpChoice.new
    @confirm_window.set_handler(:yes, method(:on_confirmed))
    @confirm_window.set_handler(:cancel, method(:back_to_list))
    @start_window = Window_MpChoice.new
    [:from_creator, :from_beginning, :from_own].each { |symbol| @start_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @start_window.set_handler(:cancel, method(:back_to_list))
    @forms ||= { :new_world => MGQ_MpWorld::Form.create, :join_hidden => MGQ_MpWorld::Form.join }
    @message ||= HINT
    @me = MGQ_MpWorld::Directory.my_id
    MGQ_MpWorld::Directory.refresh
    @refresh_frames = 0
    @look_frames = LOOK_FRAMES
    look_at_list
    take_text_result
    take_start_save
    return_to_form if @form_symbol
    show_panel
    show_info
  end

  # Asks for the player's name the first time, takes what is typed into a text box, follows a
  # running action, and keeps the list fresh.
  def update
    super

    if @ask_name
      @ask_name = false
      ask_text(:player_name, "Your name, which the others see", MGQ_Multiplayer::Player.name.to_s, :max_chars => MGQ_MpWorld::MAX_NAME_CHARS)
      return
    end

    return start_from_own if @own_start

    if form && form.editing
      update_typing
    elsif @resume_form && !@start_window.active && !Input.press?(:C) && !Input.press?(:B)
      # The press that ended the typing must not reach the form, or Enter types again at once.
      @resume_form = false
      @form_window.activate
    end

    follow_action if @busy
    show_panel
    show_field_hint

    @refresh_frames += 1
    if @refresh_frames >= REFRESH_FRAMES && !@busy
      @refresh_frames = 0
      MGQ_MpWorld::Directory.refresh
    end

    @look_frames += 1
    look_at_list if @look_frames >= LOOK_FRAMES
  rescue => e
    MGQ_MpWorld.log("world screen failed: #{e.class}: #{e.message}")
    return_scene
  end

  # Stops taking what is typed, should the screen close while a text box is typed into.
  def terminate
    MGQ_Multiplayer::Link.typing(false) if form && form.editing
    super
  end

  # Shows the list the DLL holds, if it changed.
  def look_at_list
    @look_frames = 0
    state, error, listed, admin = MGQ_MpWorld::Directory.list
    @list_state = state
    @list_error = state == "failed" ? error : nil
    @admin = admin
    entries = MGQ_MpWorld.entries(listed, state == "ready")
    @list_window.entries = entries
    show_info
  end

  # Shows at the right what the list points at: a world's details, or a form.
  def show_panel
    shown = @forms[@list_window.current_symbol]
    @form_window.form = shown if shown
    @form_window.visible = !shown.nil?
    @detail_window.visible = shown.nil?
    @detail_window.show(@list_window.current_ext, @me) unless shown
  end

  # Acts on what the text screen handed back.
  def take_text_result
    kind, text = MGQ_MpWorld.take_text_result

    case kind
    when :player_name
      MGQ_Multiplayer::Player.name = text if text
      @me = MGQ_MpWorld::Directory.my_id
      return return_scene if MGQ_Multiplayer::Player.name.nil?
    when :password
      start_action("unlock") { MGQ_MpWorld::Directory.unlock(@entry.id, text) } if text && @entry && @entry.listed
    when Array
      fill_field(kind[1], text) if text && form
    end

    @ask_name = MGQ_Multiplayer::Player.name.nil?
  end

  # Opens what can be done with the chosen world.
  def on_world
    @entry = @list_window.current_ext
    listed = @entry.listed
    creator = listed && listed.creator_id == @me
    commands = []
    commands.push(["Enter the world", :enter]) if listed || @entry.local
    commands.push([@entry.favourite ? "No longer a favourite" : "Mark as a favourite", :favourite]) if @entry.id
    commands.push(["Copy the world id", :copy_id]) if creator && listed.hidden
    commands.push(["Remove a player", :ban, listed.members.size > 1]) if creator
    commands.push(["Delete the world for everyone", :delete_world]) if creator || (listed && @admin)
    commands.push(["Copy my latest save to my game", :export_save]) if @entry.local && @entry.local.latest_save
    commands.push(["Delete my saves of it", :delete_saves]) if @entry.local
    commands.push(["Back", :cancel])
    @actions_window.start(commands)
  end

  # Enters the chosen world, asking for its password the first time, unless it has none.
  def on_enter
    if @entry.listed && @entry.listed.start == "pending"
      Sound.play_buzzer
      say("#{@entry.name} is still being set up by its creator. Try again in a moment.")
      back_to_list
    elsif @entry.local && @entry.listed.nil? && @entry.local.latest_save.nil?
      # Without the list, a first entry cannot know where the world's players start.
      refuse(@entry.gone ? "#{@entry.name} is no longer in the list: it was deleted, or you were removed." : "#{@entry.name} is not in the list right now. Try again once the list has loaded.")
      back_to_list
    elsif @entry.local
      listed = @entry.listed
      @entry.local.describe(listed.name, listed.id) if listed
      enter(@entry.local, listed && listed.start, listed && listed.choose)
    elsif @entry.listed.online >= @entry.listed.seats
      Sound.play_buzzer
      say("#{@entry.name} is full right now.")
      back_to_list
    elsif @entry.open?
      start_action("unlock") { MGQ_MpWorld::Directory.unlock(@entry.id, "") }
    else
      ask_text(:password, "The password of #{@entry.name}", "", :masked => true, :max_chars => MGQ_MpWorld::MAX_PASSWORD_CHARS)
    end
  end

  # Marks the chosen world as a favourite, or no longer.
  def on_favourite
    favourite = MGQ_MpWorld::Favourites.toggle(@entry.id)
    say(favourite ? "#{@entry.name} is a favourite now." : "#{@entry.name} is no longer a favourite.")
    look_at_list
    back_to_list
  end

  # Puts the chosen hidden world's id on the clipboard, for its creator to hand out.
  def on_copy_id
    if MGQ_MpWorld::Link.copy(@entry.id)
      say("The id of #{@entry.name} is on the clipboard. Send it#{@entry.open? ? '' : ' with the password'} to those who may join.")
    else
      Sound.play_buzzer
      say("The id could not be put on the clipboard.")
    end
    back_to_list
  end

  # Opens the list of the chosen world's players to remove one.
  def on_ban
    others = @entry.listed.members.reject { |member| member.id == @me }
    @members_window.start(others.map { |member| [member.name, :member, true, member] } + [["Back", :cancel]])
  end

  # Asks whether to remove the chosen player.
  def on_member
    @target = @members_window.current_ext
    confirm(:ban, "Remove #{@target.name} from #{@entry.name}? They cannot enter it again.", "Remove them")
  end

  # Asks whether to delete the chosen world for everyone.
  def on_delete_world
    confirm(:delete_world, "Delete #{@entry.name} for everyone? Nobody can enter it again. Saves stay on each PC.", "Delete it")
  end

  # Copies the chosen world's latest save into the player's own game, see MGQ_MpSaveExport.
  def on_export_save
    say(MGQ_MpSaveExport.export(@entry.local))
    back_to_list
  end

  # Asks whether to delete the player's saves of the chosen world.
  def on_delete_saves
    again = @entry.open? ? "You would start anew." : "You would need its password again, and start anew."
    confirm(:delete_saves, "Delete your saves of #{@entry.name}? #{@entry.listed ? again : ''}", "Delete them")
  end

  # Does what the player confirmed.
  def on_confirmed
    case @confirming
    when :ban
      start_action("ban") { MGQ_MpWorld::Directory.ban(@entry.id, @target.id) }
    when :delete_world
      start_action("delete") { MGQ_MpWorld::Directory.delete(@entry.id) }
    when :delete_saves
      say(@entry.local.delete ? "Your saves of #{@entry.name} were deleted." : "Your saves of #{@entry.name} could not be deleted.")
      look_at_list
      back_to_list
    end
  end

  # Asks for the player's name again.
  def on_rename
    ask_text(:player_name, "Your name, which the others see", MGQ_Multiplayer::Player.name.to_s, :max_chars => MGQ_MpWorld::MAX_NAME_CHARS)
  end

  # The form the player fills in, nil while the list has the cursor.
  #
  # @return [MGQ_MpWorld::Form, nil] The form.
  def form
    @form_symbol && @forms[@form_symbol]
  end

  # Moves from the list into the form it points at.
  def enter_form
    @form_symbol = @list_window.current_symbol
    @form_window.select(0)
    @form_window.activate
  end

  # Moves from the form back to the list, keeping what was filled in.
  def leave_form
    @form_symbol = nil
    @hinted = nil
    @form_window.unselect
    @form_window.deactivate
    say(HINT)
    @list_window.activate
  end

  # Puts the cursor back on the form after another screen, at the field it left from.
  def return_to_form
    @list_window.select_symbol(@form_symbol)
    @list_window.deactivate
    @form_window.form = form
    @form_window.select(@field_index || 0)
    @resume_form = true unless @busy
  end

  # Acts on the chosen field: ticks a checkbox, opens the save screen, sends the form, or starts
  # typing into a text box.
  def on_field
    field = @form_window.field
    @field_index = @form_window.index

    case field.kind
    when :check
      form[field.key] = !form[field.key]
      @form_window.refresh
      @form_window.activate
    when :save
      MGQ_MpSaveDistribution.choose(:world)
    when :button
      send_form
    else
      start_typing(field)
    end
  end

  # Starts typing into a text box in place, or on the text screen when the keyboard cannot reach
  # the game.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  def start_typing(field)
    return ask_field(field, false) unless MGQ_Multiplayer::Background.running?

    form.editing = field.key
    @typed_before = form[field.key]
    @typing_frames = 0
    MGQ_Multiplayer::Link.typing(true)
    @form_window.refresh
    say(TYPING_HINT)
  end

  # Takes what was typed into the text box, or moves the typing to the text screen, whose letters
  # a gamepad can pick, once a button is pressed that did not come from the keyboard.
  def update_typing
    field = @form_window.field
    text, keys = MGQ_Multiplayer::Link.take_typed
    @typing_frames += 1

    # The press that started the typing is still reported in its first frame.
    if keys == 0 && text.empty? && @typing_frames > 1 && MGQ_MpWorld.gamepad_pressed?
      stop_typing
      return ask_field(field, true)
    end

    text.each_char do |char|
      type(field, char)
      break unless form.editing
    end
  end

  # Types one character into the text box: Enter keeps the text if it is valid, Escape puts the
  # text back as it was, Backspace removes the last character.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  # @param char [String] The character.
  def type(field, char)
    case char
    when "\r"
      text, error = form.check(field, form[field.key])
      return refuse(error) if error

      form[field.key] = text
      Sound.play_ok
      stop_typing
    when "\e"
      form[field.key] = @typed_before
      Sound.play_cancel
      stop_typing
    when "\b"
      return if form[field.key].empty?

      form[field.key] = form[field.key][0...-1]
      Sound.play_cancel
    else
      return if char =~ /[[:cntrl:]]/

      form.add(field, char) ? Sound.play_cursor : Sound.play_buzzer
    end
    @form_window.redraw_current_item
  end

  # Stops typing into the text box and hands the cursor back to the form.
  def stop_typing
    MGQ_Multiplayer::Link.typing(false)
    form.editing = nil
    @form_window.refresh
    @hinted = nil
    @resume_form = true
  end

  # Opens the text screen for a text box.
  #
  # @param field [MGQ_MpWorld::Form::Field] The text box.
  # @param letters [Boolean] Whether to show the game's letters at once, for a gamepad.
  def ask_field(field, letters)
    ask_text([:field, field.key], field.label, form[field.key], :masked => field.kind == :password, :max_chars => field.max_chars, :allowed => field.allowed, :letters => letters)
  end

  # Fills in a text box from the text screen, if the text is valid.
  #
  # @param key [Symbol] The text box's key.
  # @param text [String] The text.
  def fill_field(key, text)
    field = form.fields.find { |candidate| candidate.key == key }
    checked, error = form.check(field, text)

    if error
      say(error)
      # Keeps the reason on screen instead of the field's hint.
      @hinted = @field_index
    else
      form[key] = checked
      @hinted = nil
    end
  end

  # Says why something typed or the form is not accepted.
  #
  # @param error [String] Why.
  def refuse(error)
    Sound.play_buzzer
    say(error)
  end

  # Shows the hint of the field the cursor is on, once it moved there.
  def show_field_hint
    return unless form && !form.editing && @form_window.index >= 0 && @form_window.index != @hinted

    @hinted = @form_window.index
    say(@form_window.field.hint)
  end

  # Sends the filled-in form, or points at the first field that keeps it from being sent.
  def send_form
    index, error = form.problem

    if error
      refuse(error)
      @form_window.select(index)
      @hinted = index
      return @resume_form = true
    end

    @form_symbol == :new_world ? create_world : join_world
  end

  # Takes the save picked on the save screen: as the new world's starting save, or as where the
  # player starts in the world they are entering, which update then enters, asking again when they
  # picked none. Called as the world screen starts again.
  def take_start_save
    purpose, index = MGQ_MpSaveDistribution.take_chosen
    return unless purpose

    if purpose == :world
      @forms[:new_world][:save] = index if index
    elsif index
      @own_start = index
      @list_window.deactivate
    else
      ask_start(@starting, @starting_from)
    end
  end

  # Makes the world the form describes.
  def create_world
    values = @forms[:new_world]
    files = values[:from_save] ? MGQ_MpSaveDistribution.files_of(values[:save]) : []
    @creating = values[:name]
    @start_files = files
    start_action("create") { MGQ_MpWorld::Directory.create(values[:name], values[:password], values[:seats].to_i, values[:hidden], values[:choose], MGQ_MpSaveDistribution.text_of(files)) }
  end

  # Opens the hidden world the form names by its id.
  def join_world
    values = @forms[:join_hidden]
    @entry = nil
    start_action("unlock") { MGQ_MpWorld::Directory.unlock(values[:id], values[:password]) }
  end

  # Starts a directory action and waits for it, the input held meanwhile.
  #
  # @param kind [String] The action's kind.
  def start_action(kind)
    close_popups

    unless yield
      Sound.play_buzzer
      say("Another request is still running. Try again in a moment.")
      return back_to_list
    end

    @busy = kind
    @list_window.deactivate
    @form_window.deactivate
    # What the action ends with must not give way to the hint of the field it was sent from.
    @hinted = @form_window.index
    say(BUSY_TEXTS[kind])
  end

  # Acts once the running action ended.
  def follow_action
    action = MGQ_MpWorld::Directory.action
    return if action["state"] == "busy"

    kind = @busy
    @busy = nil
    MGQ_MpWorld::Directory.clear

    if action["state"] == "failed"
      Sound.play_buzzer
      say(action["error"])
      return back_to_list
    end

    case kind
    when "create"
      world = MGQ_MpWorld::World.found(action["code"], @creating, action["world"])

      if world && (@start_files.empty? || MGQ_MpSaveDistribution.place(world, @start_files))
        choose = @forms[:new_world][:choose]
        # A fresh form keeps going back from the world from making it again.
        @forms[:new_world] = MGQ_MpWorld::Form.create
        leave_form
        MGQ_MpWorld::Directory.refresh
        return enter(world, "none", choose)
      end

      say(world ? "Your save could not be copied into #{@creating}." : "The world's folder could not be made.")
    when "unlock"
      return if enter_opened(action)
    when "start"
      return start_world(@fetched, true)
    when "delete"
      say("#{@entry.name} was deleted for everyone.")
    when "ban"
      say("#{@target.name} was removed from #{@entry.name}.")
    end

    MGQ_MpWorld::Directory.refresh
    back_to_list
  end

  # Enters a world whose lock was opened, from the list or by its id, or says why it cannot.
  #
  # @param action [Hash] The ended action, with the world's code, id, name and starting save.
  # @return [Boolean] Whether it went on to enter the world.
  def enter_opened(action)
    name = @entry ? @entry.name : action["name"].to_s

    if action["start"] == "pending"
      Sound.play_buzzer
      say("#{name} is still being set up by its creator. Try again in a moment.")
      return false
    end

    world = MGQ_MpWorld::World.found(action["code"], name, action["world"])

    unless world
      say("The world's folder could not be made.")
      return false
    end

    if @entry
      enter(world, @entry.listed.start, @entry.listed.choose)
    else
      enter(world, action["start"] || "none", action["choose"] == "1")
    end
    true
  end

  # Enters a world, first asking where to start or fetching its starting save when this PC has no
  # save of it yet, or says why it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param start [String, nil] How far it is with its starting save, nil when the list does not tell.
  # @param choose [Boolean, nil] Whether each new player chooses where to start, nil when the list does not tell.
  def enter(world, start, choose)
    return ask_start(world, start) if MGQ_MpSaveDistribution.ask_start?(world, choose)
    return fetch_start(world) if MGQ_MpSaveDistribution.fetch?(world, start)

    start_world(world)
  end

  # Asks a new player of a world whose players choose where to start.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param start [String] How far it is with its starting save.
  def ask_start(world, start)
    close_popups
    @list_window.deactivate
    @form_window.deactivate
    @starting = world
    @starting_from = start
    choices = []
    choices.push(["From the creator's save", :from_creator]) if start == "ready"
    choices.push(["At the beginning", :from_beginning])
    choices.push(["From one of my saves", :from_own])
    choices.push(["Back", :cancel])
    say("Where do you start in #{world.name}? A save you start from cannot be undone; At the beginning asks again until you save there.")
    @start_window.start(choices)
  end

  # Starts the world from its creator's save, fetching it first.
  def on_from_creator
    fetch_start(@starting)
  end

  # Starts the world at the beginning.
  def on_from_beginning
    @start_window.finish
    start_world(@starting)
  end

  # Opens the save screen to pick the save the player starts the world from.
  def on_from_own
    MGQ_MpSaveDistribution.choose(:own)
  end

  # Copies the save picked on the save screen into the world the player is entering, and enters it.
  # Called by update once the world screen is back.
  def start_from_own
    index = @own_start
    @own_start = nil

    return start_world(@starting, true) if MGQ_MpSaveDistribution.place(@starting, MGQ_MpSaveDistribution.files_of(index))

    # A copy that failed halfway would otherwise be the world's first save.
    MGQ_MpSaveDistribution.discard(@starting)
    refuse("Your save could not be copied into #{@starting.name}.")
    back_to_list
  end

  # Fetches a world's starting save, then enters the world.
  #
  # @param world [MGQ_MpWorld::World] The world.
  def fetch_start(world)
    @fetched = world
    start_action("start") { MGQ_MpSaveDistribution.fetch(world) }
  end

  # Enters a world from its latest save, or at the beginning without one, or says why it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  # @param placed [Boolean] Whether its save was just placed there, which is checked first and
  #   thrown away when it cannot be loaded, so the next entry starts anew instead of failing again.
  def start_world(world, placed = false)
    error = (placed && MGQ_MpSaveDistribution.check(world)) || MGQ_MpWorld.start(world, self)
    return unless error

    MGQ_MpSaveDistribution.discard(world) if placed
    refuse(error)
    back_to_list
  end

  # Asks whether to do something.
  #
  # @param what [Symbol] What is asked about.
  # @param question [String] The question.
  # @param yes [String] The command that does it.
  def confirm(what, question, yes)
    @confirming = what
    say(question)
    @confirm_window.start([[yes, :yes], ["Back", :cancel]])
  end

  # Opens the text screen.
  #
  # @param kind [Symbol, Array] What the text is for, [:field, key] for a text box of the form.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param options [Hash] See Scene_MpText#prepare.
  def ask_text(kind, caption, default, options)
    SceneManager.call(Scene_MpText)
    SceneManager.scene.prepare(kind, caption, default, options)
  end

  # Closes the small windows and goes back to the list, or to the form the player was filling in.
  def back_to_list
    close_popups
    show_info
    return if @busy

    form ? @resume_form = true : @list_window.activate
  end

  # Closes the small windows.
  def close_popups
    [@actions_window, @members_window, @confirm_window, @start_window].each { |window| window.finish }
  end

  # Says something in the lines at the top.
  #
  # @param message [String] What to say.
  def say(message)
    @message = message
    show_info
  end

  # Shows who plays, what happened last, and how the list stands.
  def show_info
    name = MGQ_Multiplayer::Player.name
    list = case @list_state
           when "loading" then "The list is being fetched . . ."
           when "failed" then "The list could not be fetched: #{@list_error}"
           end
    @info_window.show([name ? "You play as #{name}." : "You have no name yet.", @message, list])
  end
end

# The text screen, for names and passwords, and for a form's text boxes once a gamepad is used: the
# typed text in a box, with its purpose where a character's face would be. The keyboard types into
# it; the game's own letters appear below once a gamepad is used, or from the start when the
# keyboard cannot reach the game.
class Scene_MpText < Scene_MenuBase
  # Sets what the text is for and how it looks.
  #
  # @param kind [Symbol, Array] What the text is for, handed back with it.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param options [Hash] :max_chars, how long the text may be; and whichever of :masked (shown as
  #   stars), :allowed (the characters it takes) and :letters (the letters shown at once) apply.
  def prepare(kind, caption, default, options)
    @kind = kind
    @caption = caption
    @default = default
    @options = options
  end

  # Creates the windows and starts taking what is typed, the letters hidden while the keyboard
  # works, unless they were asked for.
  def start
    super
    @edit_window = Window_MpTextEdit.new(@caption, @default, @options)
    @input_window = Window_MpTextInput.new(@edit_window)
    @input_window.set_handler(:ok, method(:on_input_ok))
    @input_window.set_handler(:cancel, method(:on_input_cancel))
    MGQ_Multiplayer::Link.typing(true)
    MGQ_Multiplayer::Background.running? && !@options[:letters] ? hide_letters : show_letters
  end

  # Types what came from the keyboard, then lets the letters take a gamepad's buttons, showing
  # them once a button is pressed that did not come from the keyboard.
  #
  # A key that types also moves the game's own buttons, such as Z for OK, so the letters ignore
  # the buttons in a frame the keyboard was used.
  def update
    text, keys = MGQ_Multiplayer::Link.take_typed
    keyboard = keys > 0 || !text.empty?
    @input_window.keyboard_used = keyboard

    if !keyboard && !@input_window.visible && MGQ_MpWorld.gamepad_pressed?
      show_letters
      # The press that showed the letters picks nothing.
      @input_window.keyboard_used = true
    end

    text.each_char do |char|
      type(char)
      break if scene_changing?
    end
    super
  end

  # Hides the letters and puts the box in the middle of the screen.
  def hide_letters
    @input_window.hide
    @input_window.deactivate
    @edit_window.hint = "Type on the keyboard. Enter confirms, Esc goes back."
    @edit_window.y = (Graphics.height - @edit_window.height) / 2
  end

  # Shows the letters below the box, for a gamepad.
  def show_letters
    @edit_window.hint = nil
    @edit_window.y = @input_window.y - @edit_window.height - 8
    @input_window.show
    @input_window.activate
  end

  # Types one character: Enter confirms, Escape leaves, Backspace removes the last one.
  #
  # @param char [String] The character.
  def type(char)
    case char
    when "\r"
      @edit_window.name.empty? ? Sound.play_buzzer : on_input_ok
    when "\e"
      on_input_cancel
    when "\b"
      Sound.play_cancel if @edit_window.back
    else
      return if char =~ /[[:cntrl:]]/

      @edit_window.add(char) ? Sound.play_cursor : Sound.play_buzzer
    end
  end

  # Stops taking what is typed.
  def terminate
    MGQ_Multiplayer::Link.typing(false)
    super
  end

  # Hands the text back.
  def on_input_ok
    MGQ_MpWorld.text_result = [@kind, @edit_window.name]
    return_scene
  end

  # Leaves without a text.
  def on_input_cancel
    MGQ_MpWorld.text_result = [@kind, nil]
    return_scene
  end
end

# The lines across the top of the world screen.
class Window_MpWorldInfo < Window_Base
  # Lines the window has room for.
  LINES = 3

  # Creates the window across the top of the screen, empty.
  def initialize
    super(0, 0, Graphics.width, fitting_height(LINES))
    @lines = []
  end

  # Draws the lines, if they changed, wrapping long ones.
  #
  # @param lines [Array<String, nil>] The lines, nil ones left out.
  def show(lines)
    wrapped = lines.compact.map { |line| wrap(line) }.flatten
    return if wrapped == @lines

    @lines = wrapped
    contents.clear
    wrapped.first(LINES).each_with_index do |line, index|
      draw_text(0, index * line_height, contents_width, line_height, line)
    end
  end

  # Breaks a line into lines that fit the window.
  #
  # @param line [String] The line.
  # @return [Array<String>] The lines.
  def wrap(line)
    lines = [""]
    line.split(" ").each do |word|
      candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
      text_size(candidate).width <= contents_width || lines.last.empty? ? lines[-1] = candidate : lines.push(word)
    end
    lines
  end
end

# The worlds at the left of the world screen, then what else it offers.
class Window_MpWorldList < Window_Command
  # Width of the window.
  WIDTH = 300

  # Creates the list below the lines, reaching down to the bottom of the screen.
  #
  # @param y [Integer] The top edge.
  def initialize(y)
    @entries = []
    @height = Graphics.height - y
    super(0, y)
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns the window's height: down to the bottom of the screen.
  #
  # @return [Integer] The height.
  def window_height
    @height
  end

  # Shows other worlds, keeping the world or command chosen, so a form stays open while worlds
  # come and go above it.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The worlds.
  def entries=(entries)
    return if entries == @entries

    chosen = current_ext
    symbol = current_symbol
    @entries = entries
    clear_command_list
    make_command_list
    refresh
    again = if chosen
              @list.index { |command| command[:ext] && command[:ext].id == chosen.id && command[:ext].name == chosen.name }
            else
              @list.index { |command| command[:symbol] == symbol }
            end
    select(again || [[index, 0].max, item_max - 1].min)
  end

  # Lists the worlds, then the other commands.
  def make_command_list
    (@entries || []).each { |entry| add_command(entry.name, :world, true, entry) }
    add_command("Create new world", :new_world)
    add_command("Join a hidden world", :join_hidden)
    add_command("Change your name", :rename)
    add_command("Back", :cancel)
  end

  # Draws a world with its players online and seats, a featured one in gold, a favourite with a
  # mark, and one its creator deleted pale.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    entry = @list[index][:ext]
    return super unless entry

    rect = item_rect_for_text(index)
    change_color(entry.featured? ? MGQ_MpWorld::FEATURED_COLOR : entry.favourite ? crisis_color : normal_color, !entry.gone)
    draw_text(rect, entry.favourite ? "* #{entry.name}" : entry.name)
    draw_text(rect, "#{entry.listed.online}/#{entry.listed.seats}", 2) if entry.listed
  end
end

# The chosen world's details at the right of the world screen: who made it, who is online, and
# everyone who ever joined.
class Window_MpWorldDetail < Window_Base
  # Creates the window beside the list.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param height [Integer] The height.
  def initialize(x, y, height)
    super(x, y, Graphics.width - x, height)
    @shown = :nothing
  end

  # Shows a world, if it is another than shown.
  #
  # @param entry [MGQ_MpWorld::Entry, nil] The world, nil for none.
  # @param me [String] The player's id.
  def show(entry, me)
    return if entry == @shown

    @shown = entry
    contents.clear
    return unless entry

    lines = []
    listed = entry.listed
    lines.push([entry.name, entry.featured? ? MGQ_MpWorld::FEATURED_COLOR : system_color])

    if listed
      lines.push(["Featured: one of the relay's own worlds.", MGQ_MpWorld::FEATURED_COLOR]) if listed.featured
      lines.push(["Made by #{listed.creator_id == me ? 'you' : listed.creator_name}", normal_color])
      lines.push(["#{listed.online} of #{listed.seats} players online", normal_color])
      start = start_text(listed)
      lines.push([start, normal_color]) if start
      lines.push(["No password: anyone may enter.", normal_color]) if listed.open
      lines.push(["Hidden: only its players and the relay's admins see it in the list.", normal_color]) if listed.hidden
    elsif entry.gone
      lines.push(["Only on this PC: it was deleted, or you were removed.", normal_color])
    else
      lines.push(["Not in the list right now.", normal_color])
    end

    lines.push([entry.local ? played_text(entry.local) : "You have not entered it yet.", normal_color])
    lines.push(["", normal_color])

    if listed
      lines.push(["Players", system_color])
      listed.members.each do |member|
        name = member.id == me ? "#{member.name} (you)" : member.name
        lines.push([member.online ? "#{name} - online" : name, member.online ? power_up_color : normal_color])
      end
    end

    rows = contents_height / line_height
    lines = lines.first(rows - 1) + [["and #{lines.size - rows + 1} more", normal_color]] if lines.size > rows
    lines.each_with_index do |(text, color), row|
      change_color(color)
      draw_text(0, row * line_height, contents_width, line_height, text)
    end
  end

  # Tells where a world's new players start, unless it is the beginning for everyone.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world in the directory.
  # @return [String, nil] The text, nil for the beginning.
  def start_text(listed)
    return "Its creator is still uploading its starting save." if listed.start == "pending"
    return "New players choose: the beginning, their own save or its creator's." if listed.choose && listed.start == "ready"
    return "New players choose: the beginning or one of their own saves." if listed.choose
    return "New players start from its creator's save." if listed.start == "ready"

    nil
  end

  # Tells when the player last played a world.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [String] The text.
  def played_text(world)
    world.played_at ? "You last played it on #{world.played_at.strftime('%Y-%m-%d')}." : "You have entered it, but not played yet."
  end
end

# A small command window in the middle of the screen, closed until needed, whose commands are
# set as it opens.
class Window_MpChoice < Window_Command
  # Width of the window.
  WIDTH = 360

  # Creates the window, closed.
  def initialize
    @choices = []
    super(0, 0)
    self.openness = 0
    deactivate
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns how many rows are shown at once.
  #
  # @return [Integer] The rows, at most ten.
  def visible_line_number
    [[item_max, 1].max, 10].min
  end

  # Lists the commands set last.
  def make_command_list
    @choices.each { |name, symbol, enabled, ext| add_command(name, symbol, enabled != false, ext) }
  end

  # Opens the window with commands and takes the input.
  #
  # @param choices [Array<Array>] Each command's name, symbol, and optionally whether it is enabled and its extra value.
  def start(choices)
    @choices = choices
    clear_command_list
    make_command_list
    self.height = window_height
    create_contents
    refresh
    self.x = (Graphics.width - width) / 2
    self.y = (Graphics.height - height) / 2
    select(0)
    open
    activate
  end

  # Closes the window.
  def finish
    close
    deactivate
  end
end

# A form at the right of the world screen, in place of a world's details: its title, then text
# boxes, checkboxes, a save to choose and the button that sends it. Up and down move between rows,
# left and right between two fields on one row.
class Window_MpWorldForm < Window_Selectable
  # Width of the labels in front of the text boxes.
  LABEL_WIDTH = 120

  # Side of a checkbox.
  BOX_SIZE = 14

  # Fill behind the text of a text box.
  TEXT_BOX_COLOR = Color.new(0, 0, 0, 96)

  # What a text box being typed into shows after its text.
  CARET = "_"

  # The form shown, nil for none.
  attr_reader :form

  # Creates the window, hidden and without a form.
  #
  # @param x [Integer] The left edge.
  # @param y [Integer] The top edge.
  # @param width [Integer] The width.
  # @param height [Integer] The height.
  def initialize(x, y, width, height)
    @form = nil
    super
    self.visible = false
    deactivate
  end

  # Shows a form, if it is another than shown.
  #
  # @param form [MGQ_MpWorld::Form] The form.
  def form=(form)
    return if form.equal?(@form)

    @form = form
    unselect
    refresh
  end

  # Counts the fields.
  #
  # @return [Integer] One per field of the form.
  def item_max
    @form ? @form.fields.size : 0
  end

  # Finds the field the cursor is on.
  #
  # @return [MGQ_MpWorld::Form::Field, nil] The field, nil without a cursor.
  def field
    @form && index >= 0 ? @form.fields[index] : nil
  end

  # Places a field on its row, below the title, across the row or on its half of it.
  #
  # @param index [Integer] The field's index.
  # @return [Rect] Where it is drawn.
  def item_rect(index)
    field = @form.fields[index]
    half = contents_width / 2
    rect = Rect.new(0, (field.row + 1) * item_height, contents_width, item_height)
    rect.width = half if field.side
    rect.x = half if field.side == :right
    rect
  end

  # Tells whether the field the cursor is on can be used.
  #
  # @return [Boolean] Whether it can.
  def current_item_enabled?
    field ? @form.enabled?(field) : false
  end

  # Draws the title and every field.
  def refresh
    contents.clear
    return unless @form

    change_color(system_color)
    draw_text(0, 0, contents_width, line_height, @form.title)
    draw_all_items
  end

  # Draws a field: a text box, a checkbox, a save or the button.
  #
  # @param index [Integer] The field's index.
  def draw_item(index)
    field = @form.fields[index]
    rect = item_rect_for_text(index)
    enabled = @form.enabled?(field)

    case field.kind
    when :check
      draw_check(rect, field)
    when :button
      change_color(normal_color)
      draw_text(rect, field.label, 1)
    else
      draw_box(rect, field, enabled)
    end
  end

  # Draws a text box or the save to choose: its label, then its value on a darker box.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @param enabled [Boolean] Whether it can be used.
  def draw_box(rect, field, enabled)
    change_color(system_color, enabled)
    draw_text(rect.x, rect.y, LABEL_WIDTH, rect.height, field.label)
    box = Rect.new(rect.x + LABEL_WIDTH, rect.y + 2, rect.width - LABEL_WIDTH, rect.height - 4)
    contents.fill_rect(box, TEXT_BOX_COLOR)
    change_color(normal_color, enabled)
    draw_text(box.x + 4, rect.y, box.width - 8, rect.height, value_text(field))
  end

  # Draws a checkbox and its label, the box filled while ticked.
  #
  # @param rect [Rect] Where.
  # @param field [MGQ_MpWorld::Form::Field] The checkbox.
  def draw_check(rect, field)
    box = Rect.new(rect.x, rect.y + (rect.height - BOX_SIZE) / 2, BOX_SIZE, BOX_SIZE)
    contents.fill_rect(box, normal_color)
    contents.clear_rect(box.x + 1, box.y + 1, BOX_SIZE - 2, BOX_SIZE - 2)
    contents.fill_rect(box.x + 3, box.y + 3, BOX_SIZE - 6, BOX_SIZE - 6, normal_color) if @form[field.key]
    change_color(normal_color)
    draw_text(rect.x + BOX_SIZE + 6, rect.y, rect.width - BOX_SIZE - 6, rect.height, field.label)
  end

  # Writes what a text box or the save shows: a password as stars, and the caret while typed into.
  #
  # @param field [MGQ_MpWorld::Form::Field] The field.
  # @return [String] The text.
  def value_text(field)
    value = @form[field.key]
    return value.nil? ? "Choose one of your saves" : save_text(value) if field.kind == :save

    text = field.kind == :password ? "*" * value.size : value
    @form.editing == field.key ? text + CARET : text
  end

  # Names a save by its slot and, when its header tells it, the time played.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  # @return [String] The text.
  def save_text(index)
    header = DataManager.load_header(index) rescue nil
    played = header.is_a?(Hash) ? header[:playtime_s] : nil
    played ? "Save #{index + 1}  (#{played})" : "Save #{index + 1}"
  end

  # Moves to the row below.
  #
  # @param wrap [Boolean] Whether the cursor may wrap to the top.
  def cursor_down(wrap = false)
    move_row(1, wrap)
  end

  # Moves to the row above.
  #
  # @param wrap [Boolean] Whether the cursor may wrap to the bottom.
  def cursor_up(wrap = false)
    move_row(-1, wrap)
  end

  # Moves to the field at the right on a row of two.
  #
  # @param _wrap [Boolean] Unused.
  def cursor_right(_wrap = false)
    move_side(:right)
  end

  # Moves to the field at the left on a row of two.
  #
  # @param _wrap [Boolean] Unused.
  def cursor_left(_wrap = false)
    move_side(:left)
  end

  # Keeps the cursor still, since the form fits on one page.
  def cursor_pagedown
  end

  # Keeps the cursor still, since the form fits on one page.
  def cursor_pageup
  end

  # Moves to another row, onto the field on the same side when that row has two.
  #
  # @param step [Integer] 1 for the row below, -1 for the one above.
  # @param wrap [Boolean] Whether the cursor may wrap around.
  def move_row(step, wrap)
    rows = @form.fields.map { |candidate| candidate.row }.uniq
    at = rows.index(field.row) + step
    return unless wrap || at.between?(0, rows.size - 1)

    row = rows[at % rows.size]
    on_row = (0...item_max).select { |candidate| @form.fields[candidate].row == row }
    select(on_row.find { |candidate| @form.fields[candidate].side == field.side } || on_row.first)
  end

  # Moves to the other field of a row of two.
  #
  # @param side [Symbol] :left or :right.
  def move_side(side)
    other = (0...item_max).find { |candidate| @form.fields[candidate].row == field.row && @form.fields[candidate].side == side }
    select(other) if other
  end
end

# The text being typed, with its purpose where the game shows a character's face, as stars for a
# password, taking only the characters it allows.
class Window_MpTextEdit < Window_NameEdit
  # Stands in for the character whose name Window_NameEdit expects.
  Holder = Struct.new(:name)

  # Creates the window.
  #
  # @param caption [String] What the text is for.
  # @param text [String] The text it starts with.
  # @param options [Hash] See Scene_MpText#prepare.
  def initialize(caption, text, options)
    @caption = caption
    @masked = options[:masked]
    @allowed = options[:allowed]
    super(Holder.new(text.to_s), options[:max_chars])
  end

  # Adds a character, if the text takes it and has room.
  #
  # @param char [String] The character.
  # @return [Boolean] Whether it was added.
  def add(char)
    return false if @allowed && char !~ @allowed

    super
  end

  # Leaves no room for a face, so the text sits in the middle.
  #
  # @return [Integer] 0.
  def face_width
    0
  end

  # Shows a hint below the text, or none.
  #
  # @param hint [String, nil] The hint.
  def hint=(hint)
    @hint = hint
    refresh
  end

  # Draws the caption where the game draws a character's face, and the hint at the bottom.
  def draw_actor_face(*)
    draw_text(0, 0, contents_width, line_height, @caption, 1)
    return unless @hint

    change_color(normal_color, false)
    draw_text(0, contents_height - line_height, contents_width, line_height, @hint, 1)
    change_color(normal_color)
  end

  # Draws one character, as a star for a password.
  #
  # @param index [Integer] Its place.
  def draw_char(index)
    return super unless @masked

    rect = item_rect(index)
    rect.x -= 1
    rect.width += 4
    change_color(normal_color)
    draw_text(rect, "*")
  end
end

# The game's letters, for gamepads: they leave the text screen when Cancel is pressed with nothing
# typed, and ignore the buttons in a frame the keyboard was used.
class Window_MpTextInput < Window_NameInput
  # Whether the keyboard was used this frame.
  attr_accessor :keyboard_used

  # Moves the cursor, unless the keyboard was used this frame.
  def process_cursor_move
    super unless @keyboard_used
  end

  # Takes the buttons, unless the keyboard was used this frame.
  def process_handling
    super unless @keyboard_used
  end

  # Removes the last letter, or leaves when there is none.
  def process_back
    return super unless @edit_window.name.empty? && Input.trigger?(:B)

    Sound.play_cancel
    call_handler(:cancel)
  end
end

# Game hooks shared with other scripts, through mp_hooks.rbx.

begin
  # Before the title screen starts, a world the game came back from closes.
  MGQ_MpHooks.before(Scene_Title, :start, "mp_world") { MGQ_MpWorld.on_title_start }

  # After the title screen's update, a new game starts in a world the world screen opened, and the
  # update notice shows.
  MGQ_MpHooks.after(Scene_Title, :update, "mp_world") do
    MGQ_MpWorld.on_title_update(self) unless scene_changing?
    MGQ_MpWorld::UpdateNotice.refresh
  end
rescue => e
  MGQ_MpWorld.log("title hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first unless said otherwise, and the mod's part never
# raises.

if MGQ_MpWorld.hookable?
  begin
    MGQ_MpWorld::Files.install
  rescue => e
    MGQ_MpWorld.log("file hooks FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Bitmap
      alias mgq_mp_world_initialize initialize

      # Loads a picture below the Save folder, such as a save's thumbnail, from the open world's folder.
      def initialize(*args)
        mgq_mp_world_initialize(*MGQ_MpWorld::Files.mapped(args))
      end
    end
  rescue => e
    MGQ_MpWorld.log("picture hook FAILED: #{e.class}: #{e.message}")
  end

  begin
    class Window_TitleCommand
      alias mgq_mp_world_make_command_list make_command_list

      # Lists the title screen's commands, Multiplayer below Continue.
      def make_command_list
        mgq_mp_world_make_command_list
        MGQ_MpWorld.add_title_command(self)
      end
    end

    class Scene_Title
      alias mgq_mp_world_create_command_window create_command_window

      # Creates the title screen's commands, Multiplayer among them.
      def create_command_window
        mgq_mp_world_create_command_window
        @command_window.set_handler(:mgq_mp_world, method(:mgq_mp_world_command))
      end

      # Opens the world screen.
      def mgq_mp_world_command
        close_command_window
        SceneManager.call(Scene_MpWorlds)
      end

      alias mgq_mp_world_terminate terminate

      # Takes the update notice off the screen, then ends the title screen.
      def terminate
        MGQ_MpWorld::UpdateNotice.hide rescue nil
        mgq_mp_world_terminate
      end
    end
  rescue => e
    MGQ_MpWorld.log("title hooks FAILED: #{e.class}: #{e.message}")
  end
end
