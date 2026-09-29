#----------------------------------------------------------------
#  mp_world.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Listed the relay's worlds with their players, favourites first, entered with a password once and typed names on the keyboard
#                            - Let the creator delete a world or remove a player, and connected to a world while it is open
#      Paulinchen  2026-09-29: Created
#
#----------------------------------------------------------------

# Worlds: lasting places several players play in together, entered through Multiplayer on the
# title screen. The relay's world directory lists every world with its players; a world's password
# is asked once, after which this game remembers the world. Each world keeps its own saves and its
# own system save (Library, medals, system switches, affection) in Multiplayer/Worlds/<id>, so
# playing in a world never touches the player's own saves.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorld
  # Turns worlds off without uninstalling them.
  ENABLED = true

  # The title screen's command that opens the world screen.
  COMMAND_NAME = "Multiplayer"

  # Folder of the worlds on this PC, inside the mod folder.
  WORLDS_DIR = "Multiplayer/Worlds"

  # File of the worlds the player marked as favourites, inside the mod folder.
  FAVOURITES_FILE = "Favourites.ini"

  # Players a new world seats at most unless the player chooses otherwise.
  DEFAULT_SEATS = 4

  # Fewest players a world seats.
  MIN_SEATS = 2

  # Most players a world seats.
  MAX_SEATS = 32

  # How far Q and W change the seats of a new world at once.
  SEATS_STEP = 4

  # Longest name of a player or a world.
  MAX_NAME_CHARS = 16

  # Longest password.
  MAX_PASSWORD_CHARS = 20

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Title.method_defined?(:mgq_mp_world_start)
  end

  # Tells whether worlds can be used.
  #
  # @return [Boolean] Whether worlds are on and the Multiplayer mod's DLL is installed.
  def self.available?
    ENABLED && MGQ_Multiplayer.available?
  end

  # Writes a line to the Multiplayer mod's InGame.log.
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

  # Adds the world screen's command to the title screen, below Continue.
  #
  # @param window [Window_TitleCommand] The title screen's commands.
  def self.add_title_command(window)
    return unless available?

    list = window.instance_variable_get(:@list)
    entry = { :name => COMMAND_NAME, :symbol => :mgq_mp_world, :enabled => true, :ext => nil }
    continue_at = list.index { |command| command[:symbol] == :continue }
    continue_at ? list.insert(continue_at + 1, entry) : list.push(entry)
  rescue => e
    log("title command failed: #{e.class}: #{e.message}")
  end

  # Builds what the world screen lists: the directory's worlds, and the worlds on this PC the
  # directory no longer has, favourites first, then those played last, then by name.
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

    entries.sort_by { |entry| [entry.favourite ? 0 : 1, -(entry.local ? entry.local.played_at.to_i : 0), entry.name.downcase] }
  end

  # A world as the world screen lists it: the directory's, this PC's folder of it, or both.
  #
  # @!attribute id [String, nil] The directory's id of the world, nil for a world made before the directory.
  # @!attribute name [String] The world's name.
  # @!attribute listed [Directory::ListedWorld, nil] The world in the directory, nil once its creator deleted it.
  # @!attribute local [World, nil] The world's folder on this PC, nil before the player entered it.
  # @!attribute favourite [Boolean] Whether the player marked it as a favourite.
  # @!attribute gone [Boolean] Whether the directory no longer has it, as opposed to its list not having arrived.
  Entry = Struct.new(:id, :name, :listed, :local, :favourite, :gone)

  # Multiplayer/Multiplayer.dll's world functions: the folder id of a world code, and the
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
  end

  # The relay's world directory, through Multiplayer/Multiplayer.dll: the list of worlds, fetched
  # again whenever asked, and one action at a time.
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
    # @!attribute members [Array<Member>] Everyone who ever joined it, those online first.
    ListedWorld = Struct.new(:id, :seats, :online, :creator_id, :active, :creator_name, :name, :members)

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
    # @return [Array] The state ("idle", "loading", "ready" or "failed"), why it failed, and the worlds.
    def self.list
      state = MGQ_Multiplayer::Link.parse(MGQ_Multiplayer::Link.read('mp_dir_list', LIST_SIZE))
      worlds = []

      state[:payload].split("\n").each do |line|
        fields = line.split("\t", -1)

        case fields[0]
        when "world"
          worlds.push(ListedWorld.new(fields[1], fields[2].to_i, fields[3].to_i, fields[4], fields[5].to_i, fields[6].to_s, fields[7].to_s, []))
        when "member"
          worlds.last.members.push(Member.new(fields[1], fields[2] == "1", fields[3].to_s)) if worlds.last
        end
      end

      [state["state"] || "idle", state["error"], worlds]
    end

    # Makes a world, locked with its password.
    #
    # @param name [String] The world's name.
    # @param password [String] The password.
    # @param seats [Integer] How many players it seats at once.
    # @return [Boolean] Whether the action started.
    def self.create(name, password, seats)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_create', 'ppl').call(name + "\0", password + "\0", seats) == 1
    end

    # Opens a world's lock with its password.
    #
    # @param world [ListedWorld] The world.
    # @param password [String] The password.
    # @return [Boolean] Whether the action started.
    def self.unlock(world, password)
      MGQ_Multiplayer::Link.function('mp_dir_unlock', 'plp').call(world.id + "\0", world.seats, password + "\0") == 1
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
    # @return [Hash] "state" ("idle", "busy", "done" or "failed"), and whichever of "kind", "code", "world" and "error" apply.
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

  # The worlds the player marked as favourites, in Multiplayer/Favourites.ini.
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

  # A world on this PC: its folder in Multiplayer/Worlds, named by a hash of its code, with
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
    # It looks at the files themselves, since the game only finds a world's saves while the world is open.
    #
    # @return [Integer, String, nil] The save's index as DataManager takes it, nil without any save.
    def latest_save
      return nil unless File.directory?(save_folder)

      saves = Dir.entries(save_folder).map do |entry|
        case entry
        when /\ASave(\d{2})\.rvdata2\z/i then [$1.to_i - 1, entry]
        when /\AAutoSave(\d{2})\.rvdata2\z/i then [$1, entry]
        end
      end
      latest = saves.compact.max_by { |_, entry| File.mtime("#{save_folder}/#{entry}") }
      latest && latest[0]
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
      Files.root = nil
      $game_library, $game_system_switches, $game_global_system, count = @own
      DataManager.instance_variable_set(:@system_save_count, count)
      @own = nil
    ensure
      Files.root = nil
    end
  end
end

# The world screen, opened from the title screen: every world of the relay's directory at the left,
# the chosen one's players at the right, and what the player can do with it.
class Scene_MpWorlds < Scene_MenuBase
  # What the screen says while nothing else happened.
  HINT = "Choose a world to enter it, or make a new one."

  # Frames between two fetches of the list, ten seconds at 60 frames per second.
  REFRESH_FRAMES = 600

  # Frames between two looks at the list the DLL holds.
  LOOK_FRAMES = 20

  # What the screen says while an action runs, by the action's kind.
  BUSY_TEXTS = {
    "create" => "Making the world . . .",
    "unlock" => "Opening the world with its password . . .",
    "delete" => "Deleting the world . . .",
    "ban" => "Removing the player . . .",
  }

  # Creates the windows, fetches the list, and takes what the text screen handed back.
  def start
    super
    @info_window = Window_MpWorldInfo.new
    @list_window = Window_MpWorldList.new(@info_window.height)
    @detail_window = Window_MpWorldDetail.new(@list_window.width, @info_window.height, @list_window.height)
    @list_window.set_handler(:world, method(:on_world))
    @list_window.set_handler(:new_world, method(:on_new_world))
    @list_window.set_handler(:rename, method(:on_rename))
    @list_window.set_handler(:cancel, method(:return_scene))
    @actions_window = Window_MpChoice.new
    [:enter, :favourite, :ban, :delete_world, :delete_saves].each { |symbol| @actions_window.set_handler(symbol, method(:"on_#{symbol}")) }
    @actions_window.set_handler(:cancel, method(:back_to_list))
    @members_window = Window_MpChoice.new
    @members_window.set_handler(:member, method(:on_member))
    @members_window.set_handler(:cancel, method(:back_to_list))
    @confirm_window = Window_MpChoice.new
    @confirm_window.set_handler(:yes, method(:on_confirmed))
    @confirm_window.set_handler(:cancel, method(:back_to_list))
    @seats_window = Window_MpSeats.new
    @seats_window.set_handler(:ok, method(:on_seats))
    @seats_window.set_handler(:cancel, method(:back_to_list))
    @message ||= HINT
    @me = MGQ_MpWorld::Directory.my_id
    MGQ_MpWorld::Directory.refresh
    @refresh_frames = 0
    @look_frames = LOOK_FRAMES
    look_at_list
    take_text_result
    show_info
  end

  # Asks for the player's name the first time, follows a running action, and keeps the list fresh.
  def update
    super

    if @ask_name
      @ask_name = false
      ask_text(:player_name, "Your name, which the others see", MGQ_Multiplayer::Player.name.to_s, false, MGQ_MpWorld::MAX_NAME_CHARS)
      return
    end

    follow_action if @busy
    @detail_window.show(@list_window.current_ext, @me)

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

  # Shows the list the DLL holds, if it changed.
  def look_at_list
    @look_frames = 0
    state, error, listed = MGQ_MpWorld::Directory.list
    @list_state = state
    @list_error = state == "failed" ? error : nil
    entries = MGQ_MpWorld.entries(listed, state == "ready")
    @list_window.entries = entries
    show_info
  end

  # Acts on what the text screen handed back.
  def take_text_result
    kind, text = MGQ_MpWorld.take_text_result

    case kind
    when :player_name
      MGQ_Multiplayer::Player.name = text if text
      @me = MGQ_MpWorld::Directory.my_id
      return return_scene if MGQ_Multiplayer::Player.name.nil?
    when :world_name
      return unless text

      @new_world = { :name => text }
      ask_text(:new_password, "A password for #{text}, which the others enter it with", "", true, MGQ_MpWorld::MAX_PASSWORD_CHARS)
    when :new_password
      return unless text && @new_world

      @new_world[:password] = text
      @message = "How many players may play in #{@new_world[:name]} at once? It cannot be changed later."
      @list_window.deactivate
      @seats_window.start
    when :password
      start_action("unlock") { MGQ_MpWorld::Directory.unlock(@entry.listed, text) } if text && @entry && @entry.listed
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
    commands.push(["Remove a player", :ban, listed.members.size > 1]) if creator
    commands.push(["Delete the world for everyone", :delete_world]) if creator
    commands.push(["Delete my saves of it", :delete_saves]) if @entry.local
    commands.push(["Back", :cancel])
    @actions_window.start(commands)
  end

  # Enters the chosen world, asking for its password the first time.
  def on_enter
    if @entry.local
      @entry.local.describe(@entry.listed.name, @entry.listed.id) if @entry.listed
      enter(@entry.local)
    elsif @entry.listed.online >= @entry.listed.seats
      Sound.play_buzzer
      say("#{@entry.name} is full right now.")
    else
      ask_text(:password, "The password of #{@entry.name}", "", true, MGQ_MpWorld::MAX_PASSWORD_CHARS)
    end
  end

  # Marks the chosen world as a favourite, or no longer.
  def on_favourite
    favourite = MGQ_MpWorld::Favourites.toggle(@entry.id)
    say(favourite ? "#{@entry.name} is a favourite now." : "#{@entry.name} is no longer a favourite.")
    look_at_list
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

  # Asks whether to delete the player's saves of the chosen world.
  def on_delete_saves
    confirm(:delete_saves, "Delete your saves of #{@entry.name}? #{@entry.listed ? 'You would need its password again, and start anew.' : ''}", "Delete them")
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
    end
  end

  # Asks for a new world's name.
  def on_new_world
    ask_text(:world_name, "The new world's name", "", false, MGQ_MpWorld::MAX_NAME_CHARS)
  end

  # Asks for the player's name again.
  def on_rename
    ask_text(:player_name, "Your name, which the others see", MGQ_Multiplayer::Player.name.to_s, false, MGQ_MpWorld::MAX_NAME_CHARS)
  end

  # Makes the new world with the chosen seats.
  def on_seats
    world = @new_world
    @new_world = nil
    @creating = world[:name]
    start_action("create") { MGQ_MpWorld::Directory.create(world[:name], world[:password], @seats_window.seats) }
  end

  # Starts a directory action and waits for it, the input held meanwhile.
  #
  # @param kind [String] The action's kind.
  def start_action(kind)
    close_popups

    unless yield
      Sound.play_buzzer
      return say("Another request is still running. Try again in a moment.")
    end

    @busy = kind
    @list_window.deactivate
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
    when "create", "unlock"
      name = kind == "create" ? @creating : @entry.name
      world = MGQ_MpWorld::World.found(action["code"], name, action["world"])
      return enter(world) if world

      say("The world's folder could not be made.")
    when "delete"
      say("#{@entry.name} was deleted for everyone.")
    when "ban"
      say("#{@target.name} was removed from #{@entry.name}.")
    end

    MGQ_MpWorld::Directory.refresh
    back_to_list
  end

  # Enters a world, or says why it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  def enter(world)
    error = MGQ_MpWorld.start(world, self)
    return unless error

    Sound.play_buzzer
    say(error)
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
  # @param kind [Symbol] What the text is for.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param masked [Boolean] Whether to show the text as stars, as for a password.
  # @param max_chars [Integer] How long the text may be.
  def ask_text(kind, caption, default, masked, max_chars)
    SceneManager.call(Scene_MpText)
    SceneManager.scene.prepare(kind, caption, default, masked, max_chars)
  end

  # Closes the small windows and goes back to the list.
  def back_to_list
    close_popups
    show_info
    @list_window.activate unless @busy
  end

  # Closes the small windows.
  def close_popups
    [@actions_window, @members_window, @confirm_window, @seats_window].each { |window| window.finish }
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

# The text screen, for names and passwords: the typed text, with its purpose where a character's
# face would be, and the game's own letters below for gamepads. The keyboard types too.
class Scene_MpText < Scene_MenuBase
  # Sets what the text is for and how it looks.
  #
  # @param kind [Symbol] What the text is for, handed back with it.
  # @param caption [String] What the screen says it is for.
  # @param default [String] The text it starts with.
  # @param masked [Boolean] Whether to show the text as stars.
  # @param max_chars [Integer] How long the text may be.
  def prepare(kind, caption, default, masked, max_chars)
    @kind = kind
    @caption = caption
    @default = default
    @masked = masked
    @max_chars = max_chars
  end

  # Creates the windows and starts taking what is typed.
  def start
    super
    @edit_window = Window_MpTextEdit.new(@caption, @default, @masked, @max_chars)
    @input_window = Window_MpTextInput.new(@edit_window)
    @input_window.set_handler(:ok, method(:on_input_ok))
    @input_window.set_handler(:cancel, method(:on_input_cancel))
    MGQ_Multiplayer::Link.typing(true)
  end

  # Types what came from the keyboard, then lets the letters take a gamepad's buttons.
  #
  # A key that types also moves the game's own buttons, such as Z for OK, so the letters ignore
  # the buttons in a frame the keyboard was used.
  def update
    text, keys = MGQ_Multiplayer::Link.take_typed
    @input_window.keyboard_used = keys > 0 || !text.empty?
    text.each_char do |char|
      type(char)
      break if scene_changing?
    end
    super
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

  # Shows other worlds, keeping the one chosen if it is still there.
  #
  # @param entries [Array<MGQ_MpWorld::Entry>] The worlds.
  def entries=(entries)
    return if entries == @entries

    chosen = current_ext
    @entries = entries
    clear_command_list
    make_command_list
    refresh
    again = chosen && @list.index { |command| command[:ext] && command[:ext].id == chosen.id && command[:ext].name == chosen.name }
    select(again || [[index, 0].max, item_max - 1].min)
  end

  # Lists the worlds, then the other commands.
  def make_command_list
    (@entries || []).each { |entry| add_command(entry.name, :world, true, entry) }
    add_command("New world", :new_world)
    add_command("Change your name", :rename)
    add_command("Back", :cancel)
  end

  # Draws a world with its players online and seats, a favourite with a mark, and one its creator
  # deleted pale.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    entry = @list[index][:ext]
    return super unless entry

    rect = item_rect_for_text(index)
    change_color(entry.favourite ? crisis_color : normal_color, !entry.gone)
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
    lines.push([entry.name, system_color])

    if listed
      lines.push(["Made by #{listed.creator_id == me ? 'you' : listed.creator_name}", normal_color])
      lines.push(["#{listed.online} of #{listed.seats} players online", normal_color])
    elsif entry.gone
      lines.push(["Only on this PC: its creator deleted it, or it is from before the list.", normal_color])
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

# Chooses how many players a new world seats at most: left and right change it by one, Q and W
# by more.
class Window_MpSeats < Window_Selectable
  # Width of the window.
  WIDTH = 300

  # The chosen seats.
  attr_reader :seats

  # Creates the window, closed.
  def initialize
    super(0, 0, WIDTH, fitting_height(1))
    self.x = (Graphics.width - width) / 2
    self.y = (Graphics.height - height) / 2
    self.openness = 0
    @seats = MGQ_MpWorld::DEFAULT_SEATS
    deactivate
    refresh
  end

  # Returns how many rows the window has.
  #
  # @return [Integer] One.
  def item_max
    1
  end

  # Opens the window at the default seats and takes the input.
  def start
    @seats = MGQ_MpWorld::DEFAULT_SEATS
    refresh
    select(0)
    open
    activate
  end

  # Closes the window.
  def finish
    close
    deactivate
  end

  # Draws the seats.
  def refresh
    contents.clear
    draw_text(item_rect_for_text(0), "Players at most:  < #{@seats} >", 1)
  end

  # Adds one seat.
  #
  # @param _wrap [Boolean] Unused.
  def cursor_right(_wrap = false)
    change(1)
  end

  # Takes one seat away.
  #
  # @param _wrap [Boolean] Unused.
  def cursor_left(_wrap = false)
    change(-1)
  end

  # Adds several seats.
  def cursor_pagedown
    change(MGQ_MpWorld::SEATS_STEP)
  end

  # Takes several seats away.
  def cursor_pageup
    change(-MGQ_MpWorld::SEATS_STEP)
  end

  # Changes the seats within the allowed range.
  #
  # @param step [Integer] How many to add, negative to take away.
  def change(step)
    seats = [[@seats + step, MGQ_MpWorld::MIN_SEATS].max, MGQ_MpWorld::MAX_SEATS].min
    return if seats == @seats

    @seats = seats
    Sound.play_cursor
    refresh
  end
end

# The text being typed, with its purpose where the game shows a character's face, as stars for a password.
class Window_MpTextEdit < Window_NameEdit
  # Stands in for the character whose name Window_NameEdit expects.
  Holder = Struct.new(:name)

  # Creates the window.
  #
  # @param caption [String] What the text is for.
  # @param text [String] The text it starts with.
  # @param masked [Boolean] Whether to show the text as stars.
  # @param max_chars [Integer] How long the text may be.
  def initialize(caption, text, masked, max_chars)
    @caption = caption
    @masked = masked
    super(Holder.new(text.to_s), max_chars)
  end

  # Leaves no room for a face, so the text sits in the middle.
  #
  # @return [Integer] 0.
  def face_width
    0
  end

  # Draws the caption where the game draws a character's face.
  def draw_actor_face(*)
    draw_text(0, 0, contents_width, line_height, @caption, 1)
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

# Game hooks.
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
      alias mgq_mp_world_start start

      # Closes a world the game came back from, then starts the title screen.
      def start
        MGQ_MpWorld.on_title_start rescue nil
        mgq_mp_world_start
      end

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

      alias mgq_mp_world_update update

      # Updates the title screen, then starts a new game in a world the world screen opened.
      def update
        mgq_mp_world_update
        MGQ_MpWorld.on_title_update(self) unless scene_changing?
      end
    end
  rescue => e
    MGQ_MpWorld.log("title hooks FAILED: #{e.class}: #{e.message}")
  end
end
