#----------------------------------------------------------------
#  mp_world.rb
#
#  Changelog:
#      Paulinchen  2026-09-29: Created
#
#----------------------------------------------------------------

# Worlds: lasting places several players play in together, entered through Multiplayer on the
# title screen. Each world keeps its own saves and its own system save (Library, medals, system
# switches, affection) in Multiplayer/Worlds/<id>, so playing in a world never touches the
# player's own saves.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorld
  # Turns worlds off without uninstalling them.
  ENABLED = true

  # The title screen's command that opens the world screen.
  COMMAND_NAME = "Multiplayer"

  # Folder of the worlds on this PC, inside the mod folder.
  WORLDS_DIR = "Multiplayer/Worlds"

  # Players a new world seats at most unless the player chooses otherwise, and the range they may choose from.
  DEFAULT_SEATS = 4
  MIN_SEATS = 2
  MAX_SEATS = 32

  # How far Q and W change the seats of a new world at once.
  SEATS_STEP = 4

  # Longest name of a player or a world.
  MAX_NAME_CHARS = 16

  # The name a world joined with a code has until a player there tells the one it was given.
  UNNAMED_WORLD = "A shared world"

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

  # What the name screen handed back: the kind of name and the name, nil when the player left it.
  #
  # @return [Array, nil] [:player or :world, name or nil], nil while none waits.
  def self.take_name_result
    result = @name_result
    @name_result = nil
    result
  end

  # Keeps what the name screen hands back.
  #
  # @param result [Array] [:player or :world, name or nil].
  def self.name_result=(result)
    @name_result = result
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

  # Opens a world: from now on the game's saves and system save are the world's.
  #
  # @param world [World] The world.
  def self.enter(world)
    leave
    Dir.mkdir(world.save_folder) unless File.directory?(world.save_folder)
    System.enter(world.save_folder)
    @world = world
    world.played!
    log("entered world #{world.id}")
  end

  # Closes the open world, putting the player's own system save back.
  def self.leave
    return unless @world

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

  # Multiplayer/Multiplayer.dll's world functions.
  module Link
    # Makes the code of a new world.
    #
    # @param seats [Integer] Players the world seats at most.
    # @return [String, nil] The world code, nil when it failed.
    def self.new_code(seats)
      buffer = "\0" * 128
      length = MGQ_Multiplayer::Link.function('mp_world_new_code', 'lpl').call(seats, buffer, buffer.size)
      length > 0 ? buffer[0, length] : nil
    end

    # Names a world by its code.
    #
    # @param code [String] The world code.
    # @return [String, nil] The world's id, nil when the text is no world code.
    def self.id_of(code)
      buffer = "\0" * 64
      length = MGQ_Multiplayer::Link.function('mp_world_id', 'ppl').call(code + "\0", buffer, buffer.size)
      length > 0 ? buffer[0, length] : nil
    end

    # Reads the world code on the clipboard.
    #
    # @return [Hash] "code" with the world code, or "error" saying why there is none.
    def self.read_clipboard
      text = MGQ_Multiplayer::Link.read('mp_world_read_clipboard', 1024)
      text.empty? ? { "error" => "The clipboard could not be read." } : MGQ_Multiplayer::Link.parse(text)
    end

    # Puts a world code on the clipboard.
    #
    # @param code [String] The world code.
    # @return [Boolean] Whether the clipboard holds it.
    def self.copy_code(code)
      MGQ_Multiplayer::Link.function('mp_world_copy_code', 'p').call(code + "\0") == 1
    end
  end

  # A world on this PC: its folder in Multiplayer/Worlds, named by the world's id, with world.ini
  # (name, world code, when it was made and last played) and the world's Save folder.
  class World
    # The file inside the world's folder that describes it.
    FILE = "world.ini"

    # What a world's folder is named: its id.
    ID = /\A[0-9a-f]{12}\z/

    # Lists the worlds on this PC.
    #
    # @return [Array<World>] The worlds, the one played last first.
    def self.all
      return [] unless File.directory?(WORLDS_DIR)

      worlds = Dir.entries(WORLDS_DIR).select { |entry| entry =~ ID }.map { |id| read(id) }.compact
      worlds.sort_by { |world| -world.played_at.to_i }
    rescue => e
      MGQ_MpWorld.log("could not list the worlds: #{e.class}: #{e.message}")
      []
    end

    # Reads a world.
    #
    # @param id [String] The world's id.
    # @return [World, nil] The world, nil when its folder holds none.
    def self.read(id)
      values = MGQ_Multiplayer::Ini.read("#{folder_of(id)}/#{FILE}")
      code = values["code"]
      code && Link.id_of(code) == id ? new(id, values) : nil
    end

    # Makes a new world.
    #
    # @param name [String] The world's name.
    # @param seats [Integer] Players it seats at most.
    # @return [World, nil] The world, nil when it could not be made.
    def self.create(name, seats)
      code = Link.new_code(seats)
      code ? found(code, name) : nil
    end

    # Takes a world someone else made, by its code: the one on this PC, or a new folder for it.
    #
    # @param code [String] The world code.
    # @return [World, nil] The world, nil when the text is no world code or the folder could not be made.
    def self.adopt(code)
      id = Link.id_of(code)
      return nil unless id

      read(id) || found(code, UNNAMED_WORLD)
    end

    # Makes a world's folder and describes the world in it.
    #
    # @param code [String] The world code.
    # @param name [String] The world's name.
    # @return [World, nil] The world, nil when the folder could not be made.
    def self.found(code, name)
      id = Link.id_of(code)
      [WORLDS_DIR, folder_of(id)].each { |dir| Dir.mkdir(dir) unless File.directory?(dir) }
      world = new(id, "name" => name, "code" => code, "created" => Time.now.to_i)
      world.write ? world : nil
    rescue => e
      MGQ_MpWorld.log("could not make a world's folder: #{e.class}: #{e.message}")
      nil
    end

    # Builds the folder of a world.
    #
    # @param id [String] The world's id.
    # @return [String] The folder, relative to the game's folder.
    def self.folder_of(id)
      "#{WORLDS_DIR}/#{id}"
    end

    # The world's id.
    attr_reader :id

    # The world's name.
    attr_reader :name

    # The world code, which lets its holder in.
    attr_reader :code

    # When the world was played last.
    attr_reader :played_at

    # Creates a world from what its world.ini says.
    #
    # @param id [String] The world's id.
    # @param values [Hash] The values of its world.ini.
    def initialize(id, values)
      @id = id
      @name = values["name"].to_s.strip.empty? ? UNNAMED_WORLD : MGQ_Multiplayer.clean(values["name"])
      @code = values["code"]
      @created = values["created"].to_i
      @played_at = values["played"] ? Time.at(values["played"].to_i) : nil
    end

    # Tells how many players the world seats at most, as its code says.
    #
    # @return [Integer] The seats.
    def seats
      @code.split(";")[3].to_i
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

    # Deletes the world's folder with everything in it. Its code still lets the player back in.
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

# The world screen, opened from the title screen: the worlds on this PC, a new world, joining a
# world with a copied world code, and the player's name.
class Scene_MpWorlds < Scene_MenuBase
  # What the screen says before anything happened.
  HINT = "Enter a world, make a new one, or join one with a world code."

  # Creates the windows, and takes what the name screen handed back.
  def start
    super
    @info_window = Window_MpWorldInfo.new
    @list_window = Window_MpWorldList.new(@info_window.height)
    @list_window.set_handler(:world, method(:on_world))
    @list_window.set_handler(:new_world, method(:on_new_world))
    @list_window.set_handler(:join, method(:on_join))
    @list_window.set_handler(:rename, method(:on_rename))
    @list_window.set_handler(:cancel, method(:return_scene))
    @actions_window = Window_MpWorldActions.new
    @actions_window.set_handler(:enter, method(:on_enter))
    @actions_window.set_handler(:copy, method(:on_copy))
    @actions_window.set_handler(:delete, method(:on_delete))
    @actions_window.set_handler(:cancel, method(:back_to_list))
    @confirm_window = Window_MpWorldConfirm.new
    @confirm_window.set_handler(:yes, method(:on_delete_confirmed))
    @confirm_window.set_handler(:cancel, method(:back_to_list))
    @seats_window = Window_MpSeats.new
    @seats_window.set_handler(:ok, method(:on_seats))
    @seats_window.set_handler(:cancel, method(:back_to_list))
    @message ||= HINT
    take_name_result
    show_info
  end

  # Asks for the player's name the first time, before anything else.
  def update
    super
    return unless @ask_name

    @ask_name = false
    ask_name(:player, "")
  end

  # Acts on the name the name screen handed back.
  def take_name_result
    kind, name = MGQ_MpWorld.take_name_result

    case kind
    when :player
      MGQ_Multiplayer::Player.name = name if name
    when :world
      if name
        @new_world_name = name
        @message = "How many players may play in #{name} at once? It cannot be changed later."
        @list_window.deactivate
        @seats_window.start
      end
    end

    @ask_name = MGQ_Multiplayer::Player.name.nil? && kind != :player
    return_scene if kind == :player && MGQ_Multiplayer::Player.name.nil?
  end

  # Opens a world's actions.
  def on_world
    @world = @list_window.current_ext
    @message = "#{@world.name}: up to #{@world.seats} players."
    show_info
    @actions_window.start
  end

  # Asks for a new world's name.
  def on_new_world
    ask_name(:world, "")
  end

  # Joins the world whose code is on the clipboard, and enters it.
  def on_join
    clipboard = MGQ_MpWorld::Link.read_clipboard
    world = clipboard["code"] && MGQ_MpWorld::World.adopt(clipboard["code"])

    if world
      enter(world)
    else
      Sound.play_buzzer
      @message = clipboard["error"] || "The world could not be joined."
      back_to_list
    end
  end

  # Asks for the player's name again.
  def on_rename
    ask_name(:player, MGQ_Multiplayer::Player.name.to_s)
  end

  # Enters the chosen world.
  def on_enter
    enter(@world)
  end

  # Puts the chosen world's code on the clipboard.
  def on_copy
    if MGQ_MpWorld::Link.copy_code(@world.code)
      @message = "The code of #{@world.name} is on your clipboard. Send it to whoever may join."
    else
      Sound.play_buzzer
      @message = "The clipboard could not be written."
    end
    back_to_list
  end

  # Asks whether to delete the chosen world.
  def on_delete
    @message = "Delete #{@world.name} and your saves in it? Its code still lets you back in, from the start."
    show_info
    @confirm_window.start
  end

  # Deletes the chosen world.
  def on_delete_confirmed
    @message = @world.delete ? "#{@world.name} was deleted." : "#{@world.name} could not be deleted."
    @list_window.refresh_list
    back_to_list
  end

  # Makes the new world with the chosen seats, and enters it.
  def on_seats
    world = MGQ_MpWorld::World.create(@new_world_name, @seats_window.seats)
    @new_world_name = nil

    if world
      enter(world)
    else
      Sound.play_buzzer
      @message = "The world could not be made."
      back_to_list
    end
  end

  # Enters a world, or says why it cannot.
  #
  # @param world [MGQ_MpWorld::World] The world.
  def enter(world)
    error = MGQ_MpWorld.start(world, self)
    return unless error

    Sound.play_buzzer
    @message = error
    back_to_list
  end

  # Closes the small windows and goes back to the list.
  def back_to_list
    @actions_window.finish
    @confirm_window.finish
    @seats_window.finish
    show_info
    @list_window.activate
  end

  # Opens the name screen.
  #
  # @param kind [Symbol] :player or :world.
  # @param default [String] The name it starts with.
  def ask_name(kind, default)
    SceneManager.call(Scene_MpName)
    SceneManager.scene.prepare(kind, default)
  end

  # Shows who plays and what happened last.
  def show_info
    name = MGQ_Multiplayer::Player.name
    @info_window.show([name ? "You play as #{name}." : "You have no name yet.", @message])
  end
end

# The name screen, for the player's name and a new world's: the game's own letters, with the
# name's purpose where a character's face would be.
class Scene_MpName < Scene_MenuBase
  # What the name screen says a name is for.
  CAPTIONS = { :player => "Your name, which the others see", :world => "The new world's name" }

  # Sets what the name is for and what it starts with.
  #
  # @param kind [Symbol] :player or :world.
  # @param default [String] The name it starts with.
  def prepare(kind, default)
    @kind = kind
    @default = default
  end

  # Creates the windows.
  def start
    super
    @edit_window = Window_MpNameEdit.new(CAPTIONS[@kind], @default)
    @input_window = Window_MpNameInput.new(@edit_window)
    @input_window.set_handler(:ok, method(:on_input_ok))
    @input_window.set_handler(:cancel, method(:on_input_cancel))
  end

  # Hands the name back.
  def on_input_ok
    MGQ_MpWorld.name_result = [@kind, @edit_window.name]
    return_scene
  end

  # Leaves without a name.
  def on_input_cancel
    MGQ_MpWorld.name_result = [@kind, nil]
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
  # @param lines [Array<String>] The lines.
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

# The worlds on this PC and what else the world screen offers.
class Window_MpWorldList < Window_Command
  # Width of the window.
  WIDTH = 440

  # Rows shown at once.
  ROWS = 9

  # Creates the list below the lines.
  #
  # @param y [Integer] The top edge.
  def initialize(y)
    super(0, y)
    self.x = (Graphics.width - width) / 2
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Returns how many rows are shown at once.
  #
  # @return [Integer] The rows.
  def visible_line_number
    [item_max, ROWS].min
  end

  # Lists the worlds, then the other commands.
  def make_command_list
    MGQ_MpWorld::World.all.each { |world| add_command(world.name, :world, true, world) }
    add_command("New world", :new_world)
    add_command("Join with a copied world code", :join)
    add_command("Change your name", :rename)
    add_command("Back", :cancel)
  end

  # Draws a world with its seats and when it was played last, and the other commands as they are.
  #
  # @param index [Integer] The row.
  def draw_item(index)
    world = @list[index][:ext]
    return super unless world

    rect = item_rect_for_text(index)
    draw_text(rect, world.name)
    played = world.played_at ? world.played_at.strftime("%Y-%m-%d") : "new"
    draw_text(rect, "#{world.seats} players, #{played}", 2)
  end

  # Lists the worlds again, as after one was deleted.
  def refresh_list
    clear_command_list
    make_command_list
    self.height = window_height
    refresh
    select([index, item_max - 1].min)
  end
end

# A small command window in the middle of the screen, closed until needed.
class Window_MpWorldPopup < Window_Command
  # Width of the window.
  WIDTH = 300

  # Creates the window, closed.
  def initialize
    super(0, 0)
    self.x = (Graphics.width - width) / 2
    self.y = (Graphics.height - height) / 2
    self.openness = 0
    deactivate
  end

  # Returns the window's width.
  #
  # @return [Integer] The width.
  def window_width
    WIDTH
  end

  # Opens the window on its first command and takes the input.
  def start
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

# What can be done with a world.
class Window_MpWorldActions < Window_MpWorldPopup
  # Lists the actions.
  def make_command_list
    add_command("Enter the world", :enter)
    add_command("Copy the world code", :copy)
    add_command("Delete the world", :delete)
    add_command("Back", :cancel)
  end
end

# Asks whether to delete a world.
class Window_MpWorldConfirm < Window_MpWorldPopup
  # Lists the answers.
  def make_command_list
    add_command("Delete it", :yes)
    add_command("Keep it", :cancel)
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

# The name being typed, with its purpose where the game shows a character's face.
class Window_MpNameEdit < Window_NameEdit
  # Stands in for the character whose name Window_NameEdit expects.
  Holder = Struct.new(:name)

  # Creates the window.
  #
  # @param caption [String] What the name is for.
  # @param name [String] The name it starts with.
  def initialize(caption, name)
    @caption = caption
    super(Holder.new(name.to_s), MGQ_MpWorld::MAX_NAME_CHARS)
  end

  # Leaves no room for a face, so the name sits in the middle.
  #
  # @return [Integer] 0.
  def face_width
    0
  end

  # Draws the caption where the game draws a character's face.
  def draw_actor_face(*)
    draw_text(0, 0, contents_width, line_height, @caption, 1)
  end
end

# The game's letters, which leave the name screen when Cancel is pressed with nothing typed.
class Window_MpNameInput < Window_NameInput
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
