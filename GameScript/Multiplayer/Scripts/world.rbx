#----------------------------------------------------------------
#  world.rbx
#
#  Changelog:
#      Paulinchen  2026-10-06: Left the world once the player backed out of its new game, as when a question before New Game is cancelled
#                            - Added the form of the player's name
#                            - Left Allow data mismatch unticked in a new world's form
#                            - Kept a mod added by name in the mod picker when unlisted, removed only on its own
#                            - Listed the installed mods for the mod picker, which names a world's mods in the forms, and took up to 300 characters of them
#                            - Sent a world's mod settings on their own, and no longer with an edit
#                            - Read and sent a world's mod hashes and mod settings from its creator
#                            - Found a required mod's script in the Patch folder, and read the folder anew when asked
#      Paulinchen  2026-10-04: Showed the update notice in a message box that stays until the player closes it
#                            - Greyed out the title command once the update check answers, and kept an outdated game out of worlds
#                            - Kept the 50 hidden worlds added last, as many as the relay lists, so ids of deleted worlds do not crowd new ones out
#                            - Removed Form#add, since MGQ_MpUi::TextEdit takes what is typed
#                            - Renamed from mp_world.rbx
#                            - Let the creator describe a world, name the mods it needs and keep out games whose data differs from theirs
#                            - Told a game's data from another's by which entries of the database and which maps exist
#                            - Kept the editor of the text box being typed into with its form
#                            - Took a mod written with an exclamation mark in front as required, and looked for its script in the Patch folder
#                            - Took a mod written with a question mark in front as essential, which no script tells of
#                            - Let a world's creator replace its game data with that of their game as it is now, in the edit form too
#                            - Told two readings of the same world apart from a changed one, so the world screen draws only what changed
#                            - Marked a world as a favourite as its creator makes it, and took descriptions of up to 1000 characters
#                            - Split the mods a world needs at each semicolon, and said create where a text said make
#                            - Added a hidden world to the list by its id instead of entering it at once, and kept the ids added
#                            - Let the creator or an admin change a world's Max Players, mods and description in a form of its own
#                            - Shortened the fields' hints to the two lines the world screen has for them
#                            - Grouped the forms' fields, renamed From my save to Shared save and Players choose their start to Player's choice
#      Paulinchen  2026-10-03: Read and wrote the game's private fields and called its private methods through MGQ_MpGame
#                            - Moved the text screen into world_text.rbx and the world screen with its windows into world_screen.rbx
#                            - Logged through MGQ_MpLog
#                            - Put the player's own system save and Save folder back when a world's system save cannot be loaded
#      Paulinchen  2026-10-02: Told how many players a world seats, from its code
#                            - Offered to copy a world's latest save into the player's own game
#                            - Made worlds without a password, which their players enter without being asked for one
#                            - Showed the featured worlds, which the relay's admins make, in gold after the favourites
#                            - Followed the title screen's start and update through core_hooks.rbx
#                            - Put the Save folder back in one place as a world closes
#                            - Let the creator tick Players choose, after which each new player starts at the beginning, from one of their own saves or from the starting save
#      Paulinchen  2026-10-01: Said that the relay's admins see hidden worlds too
#      Paulinchen  2026-09-30: Let the relay's admins see every world, hidden ones too, and delete any
#                            - Moved into Patch/Multiplayer/Scripts as world.rbx, which Multiplayer.rb loads, with the worlds in Patch/Multiplayer/Worlds
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
# ones only for their players and the relay's admins; others add a hidden world to their list by its id. An
# admin may delete any world, and the admins' featured worlds show in gold. A world's password, if
# it has one, is asked once, after which this game remembers the world. Each world keeps its own saves and its
# own system save (Library, medals, system switches, affection) in Patch/Multiplayer/Worlds/<id>, so
# playing in a world never touches the player's own saves. A new world's players start at the
# beginning, from one of its creator's saves, or where each of them chooses (world_save_distribution.rbx).
# A world's details show what its creator wrote about it and the mods it needs, and whether the
# player's game data has the same entries as the creator's; a game that differs is warned, or kept
# out when the creator said so.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorld
  # Turns worlds off without uninstalling them.
  ENABLED = true

  # The title screen's command that opens the world screen.
  COMMAND_NAME = "Multiplayer"

  # Folder of the worlds on this PC, inside the mod folder.
  WORLDS_DIR = "Patch/Multiplayer/Worlds"

  # The folder the game loads its mods' scripts from.
  PATCH_DIR = "Patch"

  # File of the worlds the player marked as favourites, inside the mod folder.
  FAVOURITES_FILE = "Favourites.ini"

  # File of the hidden worlds the player added to their list by their ids, inside the mod folder.
  ADDED_FILE = "Added.ini"

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

  # Longest description of a world.
  MAX_DESCRIPTION_CHARS = 1000

  # Longest text that names the mods a world needs.
  MAX_MODS_CHARS = 300

  # Scripts every player of a world has, which the mod picker leaves out: the mod loader, this mod
  # and Mod Config Remake, which ships with it. Compared by mod_key.
  SHARED_SCRIPTS = %w[patch multiplayer 0modconfigremake]

  # Lines of the description the create form shows at once.
  DESCRIPTION_LINES = 4

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

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "world"

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
    return MGQ_Multiplayer::UPDATE_MESSAGE unless available?

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
    return watch_new_game(scene) if @pending == :starting
    return unless @pending == :new_game

    @pending = nil
    log("new game in world #{@world.id}") if @world
    scene.command_new_game
    # New Game may ask something first and leave the title screen only after the answer.
    @pending = :starting unless MGQ_MpGame.call(scene, :scene_changing?)
  rescue => e
    @pending = nil
    leave
    log("could not start a new game in a world: #{e.class}: #{e.message}")
  end

  # Leaves the world once the player backed out of its new game: the title's commands take the
  # input again. Called by the title screen every frame while New Game asks something first.
  #
  # @param scene [Scene_Title] The title screen.
  def self.watch_new_game(scene)
    commands = MGQ_MpGame.get(scene, :command_window)
    return unless commands && !commands.disposed? && commands.active

    @pending = nil
    log("backed out of the new game in world #{@world.id}") if @world
    leave
  end

  # Notes that the world's new game started. Called as the game sets a new game up.
  def self.new_game_started
    @pending = nil if @pending == :starting
  end

  # Adds the world screen's command to the title screen, below Continue: greyed out, with
  # UpdateNotice saying why, once a newer release is out.
  #
  # @param window [Window_TitleCommand] The title screen's commands.
  def self.add_title_command(window)
    return unless MGQ_Multiplayer.available?

    list = MGQ_MpGame.get(window, :list)
    entry = { :name => COMMAND_NAME, :symbol => :mgq_mp_world, :enabled => !MGQ_Multiplayer.outdated?, :ext => nil }
    continue_at = list.index { |command| command[:symbol] == :continue }
    continue_at ? list.insert(continue_at + 1, entry) : list.push(entry)
  rescue => e
    log("title command failed: #{e.class}: #{e.message}")
  end

  # A message box on every title screen once a newer release of the mod is out, which holds the
  # buttons until the player closes it, so the title menu cannot be used past it unread.
  module UpdateNotice
    # The box's title, the newer version filled in.
    TITLE = "Monster Girl Quest! Online %s is out"

    # What the box says.
    TEXT = "Close the game and run Patch\\Multiplayer\\Update.bat to update. Until then, Multiplayer and PvP battles stay off."

    # The hint at the bottom of the box.
    HINT = "Enter, Esc or a click: close"

    # Shows the box once a newer release is out, and closes it on confirm, cancel or a click. Called
    # every update of the title screen.
    #
    # @return [Boolean] Whether the box showed just now.
    def self.refresh
      return false unless SceneManager.scene.is_a?(Scene_Title)

      if @box
        close if @box.visible && closed_by_player?
        return false
      end
      return false unless MGQ_Multiplayer.available? && (version = MGQ_Multiplayer.newer_version)

      show(version)
      true
    end

    # Takes the box off the screen, so the next title screen shows it again. Called when the title
    # screen ends.
    def self.hide
      return unless @box

      MGQ_Multiplayer::Capture.stop(:update_notice)
      @box.dispose
      @box = nil
    end

    # Shows the box and takes the buttons from the title menu.
    #
    # @param version [String] The newer release's version.
    def self.show(version)
      @box = Sprite_MpMessageBox.new
      @box.show(format(TITLE, version), TEXT, HINT)
      MGQ_MpWorld.log("update notice shown for #{version}")
      MGQ_Multiplayer::Capture.start(:update_notice)
      # Windows keeps a click until it is asked for, so one from before the box would close it.
      MGQ_Multiplayer::Mouse.clicked?
    end

    # Reports whether the player closed the box this frame.
    #
    # @return [Boolean] Whether confirm, cancel or the left mouse button went down.
    def self.closed_by_player?
      capture = MGQ_Multiplayer::Capture
      # The mouse is asked every frame, so a click in a frame a key closed the box never counts later.
      clicked = MGQ_Multiplayer::Mouse.clicked?
      capture.trigger?(:C) || capture.trigger?(:B) || clicked
    end

    # Hides the box for the rest of this title screen and gives the buttons back.
    def self.close
      Sound.play_ok
      @box.visible = false
      MGQ_Multiplayer::Capture.stop(:update_notice)
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

    # Tells everything the world screen shows of the world, by value. Every reading of the list
    # makes new entries, so only this tells a changed world from the same one read again.
    #
    # @return [Array] What it shows.
    def signature
      [id, name, listed, favourite, gone, local && [local.name, local.directory_id, local.played_at.to_i]]
    end

    # Lists what of the player's game data differs from that of the world's creator.
    #
    # @return [Array<String>, nil] The parts that differ, none when the games match, nil when the directory does not tell.
    def differing
      listed.nil? ? nil : GameData.differing(listed.data)
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

  # What tells one game's data from another's: which entries of the database and which maps exist,
  # so a mod that adds or removes any is noticed.
  module GameData
    # The fingerprint's format, which both games must share to be compared.
    FORMAT = 1

    # What the fingerprint covers, in its order, as a difference is called.
    PARTS = ["actors", "classes", "skills", "items", "weapons", "armors", "enemies", "states", "troops", "common events", "maps"]

    # Most parts a text names before it counts the rest.
    NAMED_PARTS = 4

    # Writes the fingerprint of this game's data, once per session.
    #
    # It reads whether an entry has a name, never the name itself, so a translated game matches
    # the untranslated one as long as both name the same entries.
    #
    # @return [String] FORMAT, then a checksum per part; empty when the data could not be read.
    def self.fingerprint
      @fingerprint ||= "#{FORMAT}:" + ids.map { |list| format("%08x", Zlib.crc32(list.join(","))) }.join(".")
    rescue => e
      MGQ_MpWorld.log("reading the game data failed: #{e.class}: #{e.message}")
      ""
    end

    # Lists the ids that exist of each part.
    #
    # @return [Array<Array<Integer>>] The ids, per part in the order of PARTS.
    def self.ids
      named = [$data_actors, $data_classes, $data_skills, $data_items, $data_weapons, $data_armors, $data_enemies, $data_states].map do |entries|
        existing(entries) { |entry| !entry.name.to_s.empty? }
      end
      named + [existing($data_troops) { |troop| !troop.members.empty? }, existing($data_common_events) { |event| event.list.size > 1 }, map_ids]
    end

    # Lists the ids of the maps, as the game numbers them: those of each further map folder a
    # thousand on from the folder before.
    #
    # @return [Array<Integer>] The ids.
    def self.map_ids
      ids = []
      MGQ_MpGame.get($data_mapinfos, :map_lists).each_with_index do |maps, folder|
        maps.keys.each { |id| ids << folder * 1000 + id }
      end
      ids.sort
    end

    # Lists the ids of the entries that are more than an empty place.
    #
    # @param entries [Array] A part of the database, by id.
    # @yieldparam entry [Object] An entry.
    # @yieldreturn [Boolean] Whether it is in use.
    # @return [Array<Integer>] The ids.
    def self.existing(entries)
      (0...entries.size).select { |id| entries[id] && yield(entries[id]) }
    end

    # Lists what of this game's data differs from another game's.
    #
    # @param other [String, nil] The other game's fingerprint.
    # @return [Array<String>, nil] The parts that differ, none when the games match, nil when they cannot be compared.
    def self.differing(other)
      return nil if other.to_s.empty?

      format, mine = fingerprint.split(":", 2)
      other_format, theirs = other.to_s.split(":", 2)
      return nil unless mine && theirs && format == other_format

      mine = mine.split(".")
      theirs = theirs.split(".")
      return nil unless mine.size == PARTS.size && theirs.size == PARTS.size

      (0...PARTS.size).select { |index| mine[index] != theirs[index] }.map { |index| PARTS[index] }
    end

    # Names parts in a sentence, the first few by name.
    #
    # @param parts [Array<String>] The parts.
    # @param named [Integer] Most parts named before the rest is counted.
    # @return [String] The text, such as "skills, items and 3 more".
    def self.text(parts, named = NAMED_PARTS)
      return parts.join(", ") if parts.size <= named

      "#{parts.first(named).join(', ')} and #{parts.size - named} more"
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
    # @!attribute strict [Boolean] Whether only games with the same data as its creator's may enter.
    # @!attribute data [String] Its creator's game data, see GameData.fingerprint; empty when unknown.
    # @!attribute mods [String] The mods it needs, as its creator wrote them.
    # @!attribute description [String] What it is about, as its creator wrote it.
    # @!attribute mod_hashes [String] Its creator's hashes of required mods outside the mod catalog, "name=hash" pairs separated by semicolons.
    # @!attribute settings [String] Its creator's settings of the mods it names, "key=type:value" pairs separated by semicolons.
    ListedWorld = Struct.new(:id, :seats, :online, :creator_id, :active, :creator_name, :name, :start, :members, :hidden, :choose, :open, :featured, :strict, :data, :mods, :description, :mod_hashes, :settings)

    # A player of a world.
    #
    # @!attribute id [String] The player's id.
    # @!attribute online [Boolean] Whether the player is in the world now.
    # @!attribute name [String] The player's name.
    Member = Struct.new(:id, :online, :name)

    # Bytes the DLL may write the list into at first. A larger list asks for a larger buffer.
    LIST_SIZE = 65_536

    # Fetches the list again, with the hidden worlds the player added to it.
    def self.refresh
      MGQ_Multiplayer::Link.function('mp_dir_watch', 'p').call(Added.all.join(",") + "\0")
      MGQ_Multiplayer::Link.function('mp_dir_refresh', 'v').call
    end

    # Looks a world up by its id alone; the action tells its name.
    #
    # @param id [String] The world's id.
    # @return [Boolean] Whether the action started.
    def self.find(id)
      MGQ_Multiplayer::Link.function('mp_dir_find', 'p').call(id + "\0") == 1
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
          worlds.push(ListedWorld.new(fields[1], fields[2].to_i, fields[3].to_i, fields[4], fields[5].to_i, fields[6].to_s, fields[7].to_s, fields[8] || "none", [], fields[9] == "1", fields[10] == "1", fields[11] == "1", fields[12] == "1", fields[13] == "1", fields[14].to_s, fields[15].to_s, fields[16].to_s, fields[17].to_s, fields[18].to_s))
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
    # @param about [Hash] Whichever of :description, :mods, :data (the creator's game data), :strict (true when only games with the same data may enter), :mod_hashes and :settings apply.
    # @return [Boolean] Whether the action started.
    def self.create(name, password, seats, hidden, choose, start, about = {})
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_create', 'pplllpppplpp').call(name + "\0", password + "\0", seats, hidden ? 1 : 0, choose ? 1 : 0, start + "\0",
                                                                           about[:description].to_s + "\0", about[:mods].to_s + "\0", about[:data].to_s + "\0", about[:strict] ? 1 : 0,
                                                                           about[:mod_hashes].to_s + "\0", about[:settings].to_s + "\0") == 1
    end

    # Opens a world's lock with its password; the action tells the world's name, its starting save,
    # whether new players choose where to start, the mods it needs and which games may enter too, so
    # a hidden world is joined by its id alone.
    #
    # @param id [String] The world's id.
    # @param password [String] The password.
    # @return [Boolean] Whether the action started.
    def self.unlock(id, password)
      MGQ_Multiplayer::Link.function('mp_dir_unlock', 'pp').call(id + "\0", password + "\0") == 1
    end

    # Changes a world's seats, description and mods, which its creator or an admin may, and for its
    # creator the hashes of its required mods outside the catalog.
    #
    # @param id [String] The world.
    # @param seats [Integer] How many players it seats at once.
    # @param description [String] What it is about, empty for nothing.
    # @param mods [String] The mods it needs, empty for none.
    # @param mod_hashes [String, nil] The creator's mod hashes, nil to leave them, as an admin must.
    # @return [Boolean] Whether the action started.
    def self.edit(id, seats, description, mods, mod_hashes = nil)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_edit', 'plppppl').call(id + "\0", seats, description + "\0", mods + "\0", mod_hashes.to_s + "\0", mod_hashes ? 1 : 0) == 1
    end

    # Replaces a world's mod settings, which its creator or an admin may.
    #
    # @param id [String] The world.
    # @param settings [String] "key=type:value" pairs separated by semicolons.
    # @return [Boolean] Whether the action started.
    def self.set_settings(id, settings)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_set_settings', 'pp').call(id + "\0", settings + "\0") == 1
    end

    # Replaces a world's game data with this game's as it is now, which only its creator may.
    #
    # @param id [String] The world.
    # @return [Boolean] Whether the action started; not while this game's data cannot be read.
    def self.set_data(id)
      MGQ_Multiplayer::Player.share
      MGQ_Multiplayer::Link.function('mp_dir_set_data', 'pp').call(id + "\0", GameData.fingerprint + "\0") == 1
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
      text = MGQ_Multiplayer::Link.read('mp_dir_action', 2048)
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

  # Splits the mods a world needs, as its creator wrote them, at each semicolon. A mod written
  # with an exclamation mark in front is required, one with a question mark essential.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Each mod's name: the required ones first, then the essential ones, none for an empty text.
  def self.mods_of(text)
    names = text.to_s.split(";").map { |mod| mod.strip.sub(/\A[!?]\s*/, "") }.reject { |mod| mod.empty? }
    required = required_mods(text)
    essential = essential_mods(text)
    (names & required) + (names & essential) + (names - required - essential)
  end

  # Lists the mods a world's creator marked as required, with an exclamation mark in front: a
  # game needs their script to enter, see installed_mod?.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Their names.
  def self.required_mods(text)
    marked_mods(text, /!/)
  end

  # Lists the mods a world's creator marked as essential, with a question mark in front: they
  # stand out, but nothing is looked for, since a mod of data files has no script.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Their names.
  def self.essential_mods(text)
    marked_mods(text, /\?/)
  end

  # Lists the names of the mods written with a mark in front, without the mark.
  #
  # @param text [String, nil] The mods as written.
  # @param mark [Regexp] The mark.
  # @return [Array<String>] Their names.
  def self.marked_mods(text, mark)
    text.to_s.split(";").map { |mod| mod.strip[/\A#{mark}\s*(\S.*)\z/, 1] }.compact
  end

  # Tells whether a mod's script is installed: a .rb file of the mod's name anywhere in the Patch
  # folder, whatever its case and whether it writes spaces, underscores or hyphens.
  #
  # @param name [String] The mod's name, with or without ".rb".
  # @return [Boolean] Whether it is; also when the folder cannot be read, so nobody is kept out by mistake.
  def self.installed_mod?(name)
    @installed ||= Dir.glob("#{PATCH_DIR}/**/*.rb").map { |path| mod_key(File.basename(path)) }
    @installed.include?(mod_key(name))
  rescue => e
    log("reading the Patch folder failed: #{e.class}: #{e.message}")
    true
  end

  # Finds a mod's script in the Patch folder, as installed_mod? does.
  #
  # @param name [String] The mod's name, with or without ".rb".
  # @return [String, nil] Its path relative to the game's folder, nil when it is not installed or the folder cannot be read.
  def self.installed_path(name)
    @installed_paths ||= Dir.glob("#{PATCH_DIR}/**/*.rb").each_with_object({}) { |path, paths| paths[mod_key(File.basename(path))] ||= path }
    @installed_paths[mod_key(name)]
  rescue => e
    log("reading the Patch folder failed: #{e.class}: #{e.message}")
    nil
  end

  # Lists the mods the Patch folder holds, for the mod picker: each script once, by its file's name,
  # without the scripts every player has.
  #
  # @return [Array<String>] The names, sorted whatever their case; none when the folder cannot be read.
  def self.installed_mod_names
    names = Dir.glob("#{PATCH_DIR}/**/*.rb").map { |path| File.basename(path, ".rb") }
    names.reject { |name| SHARED_SCRIPTS.include?(mod_key(name)) }.uniq { |name| mod_key(name) }.sort_by { |name| name.downcase }
  rescue => e
    log("reading the Patch folder failed: #{e.class}: #{e.message}")
    []
  end

  # Forgets which scripts the Patch folder holds, so the next look reads it anew.
  def self.forget_installed
    @installed = nil
    @installed_paths = nil
  end

  # Lists the required mods of a world that this game lacks.
  #
  # @param text [String, nil] The mods as the world's creator wrote them.
  # @return [Array<String>] Their names.
  def self.missing_mods(text)
    required_mods(text).reject { |mod| installed_mod?(mod) }
  end

  # Turns a mod's name or its script's file name into what the two are compared by.
  #
  # @param name [String] The name.
  # @return [String] The name in lower case, without ".rb", spaces, underscores and hyphens.
  def self.mod_key(name)
    name.to_s.downcase.sub(/\.rb\z/, "").gsub(/[\s_\-]/, "")
  end

  # The hidden worlds the player added to their list by their ids, which the relay lists for
  # whoever names them.
  module Added
    # Most worlds kept, as many as the relay lists by their ids for one player.
    MAX = 50

    # Lists the worlds added.
    #
    # @return [Array<String>] Their directory ids, the one added last at the end.
    def self.all
      MGQ_Multiplayer::Ini.read(MGQ_Multiplayer.path(ADDED_FILE)).keys
    end

    # Adds a world, and forgets those added longest ago beyond MAX.
    #
    # The ids of deleted worlds are never listed again and so never removed by hand; without the
    # limit they would crowd the newest ones out of what the relay lists.
    #
    # @param id [String] The world's directory id.
    def self.add(id)
      values = MGQ_Multiplayer::Ini.read(MGQ_Multiplayer.path(ADDED_FILE))
      values.delete(id)
      values[id] = "1"
      values.shift while values.size > MAX
      MGQ_Multiplayer::Ini.write(MGQ_Multiplayer.path(ADDED_FILE), values)
    end

    # Takes a world off the list again.
    #
    # @param id [String] The world's directory id.
    def self.remove(id)
      values = MGQ_Multiplayer::Ini.read(MGQ_Multiplayer.path(ADDED_FILE))
      values.delete(id)
      MGQ_Multiplayer::Ini.write(MGQ_Multiplayer.path(ADDED_FILE), values)
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

    # Marks a world as a favourite, if it is none yet.
    #
    # @param id [String] The world's directory id.
    def self.add(id)
      toggle(id) unless all.include?(id)
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
      MGQ_MpWorld.log("could not create a world's folder: #{e.class}: #{e.message}")
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

    # Takes the world's name, directory id and seats, as the directory says them.
    #
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @param seats [Integer, nil] How many players it seats now, which its creator may change; nil to keep what the code tells.
    def describe(name, directory_id, seats = nil)
      @name = MGQ_Multiplayer.clean(name)
      @directory_id = directory_id
      parts = @code.to_s.split(";")
      @code = (parts[0...-1] + [seats.to_s]).join(";") if seats && parts.size > 3 && parts.last =~ /\A\d+\z/
    end

    # The world's folder.
    #
    # @return [String] The folder, relative to the game's folder.
    def folder
      World.folder_of(@id)
    end

    # How many players the world seats at once, which the last field of its code tells.
    #
    # @return [Integer] The seats, 0 for a code that tells none.
    def seats
      @code.to_s.split(";").last.to_i
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
    # A world's system save that cannot be loaded leaves the player's own in place.
    #
    # @param folder [String] The folder of the world's saves.
    def self.enter(folder)
      DataManager.save_system
      @own = [$game_library, $game_system_switches, $game_global_system, MGQ_MpGame.get(DataManager, :system_save_count)]
      Files.root = folder
      $game_library = $game_system_switches = $game_global_system = nil
      DataManager.setup_system
    rescue
      # Without this the game would go on in the world's folder with no world open, and the next
      # world would keep the half-loaded system save as the player's own.
      put_back
      raise
    end

    # Writes the world's system save and puts the player's own back.
    def self.leave
      return unless @own

      DataManager.save_system
    ensure
      put_back
    end

    # Puts the player's own system save and Save folder back.
    def self.put_back
      Files.root = nil
      return unless @own

      $game_library, $game_system_switches, $game_global_system, count = @own
      MGQ_MpGame.set(DataManager, :system_save_count, count)
      @own = nil
    end
  end

  # A form of the world screen: its fields, laid out in rows, and what is filled in.
  class Form
    # A field of a form: a text box (:text, :password, :number or :id), a box of several lines (:area), a checkbox (:check), a save
    # to choose (:save), the mods picked in the mod picker (:mods) or the button that sends the form (:button).
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

      # Whether a text box may stay empty.
      attr_reader :optional

      # The heading of the panel it is in, nil for a field outside every panel.
      attr_reader :group

      # How many lines a box of several lines shows.
      attr_reader :lines

      # What the lines at the top of the world screen say while the cursor is on the field.
      attr_reader :hint

      # Creates a field.
      #
      # @param key [Symbol] What the form keeps its value under.
      # @param kind [Symbol] What kind of field it is.
      # @param label [String] What it is called.
      # @param row [Integer] The row it is on.
      # @param hint [String] What the lines at the top say while the cursor is on it.
      # @param options [Hash] Whichever of :side, :max_chars, :allowed, :needs, :optional, :group and :lines apply.
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
        @optional = options[:optional] == true
        @group = options[:group]
        @lines = options[:lines] || 1
      end

      # Tells whether the field is a text box, typed into.
      #
      # @return [Boolean] Whether it is.
      def typed?
        [:text, :password, :number, :id, :area].include?(@kind)
      end
    end

    # The form of a new world.
    #
    # @return [Form] The form, empty but for the default seats.
    def self.create
      fields = [
        Field.new(:name, :text, "Name", 0, "The name everyone sees in the list.", :max_chars => MAX_NAME_CHARS, :group => "World"),
        Field.new(:password, :password, "Password", 1, "Typed once to enter the world. Left empty, anyone may enter.", :max_chars => MAX_PASSWORD_CHARS, :side => :left, :group => "World"),
        Field.new(:seats, :number, "Max Players", 1, "Players in the world at once, #{MIN_SEATS} to #{MAX_SEATS}.", :max_chars => MAX_SEATS.to_s.size, :allowed => /\A\d\z/, :side => :right, :group => "World"),
        Field.new(:hidden, :check, "Hidden", 2, "Only its players see it in the list. Others add it with its id.", :side => :left, :group => "World"),
        Field.new(:from_save, :check, "Shared save", 3, "New players start from one of your saves. Fixed once created.", :side => :left, :group => "Starting point"),
        Field.new(:choose, :check, "Player's choice", 3, "New players pick their start: the opening or a save. Fixed once created.", :side => :right, :group => "Starting point"),
        Field.new(:save, :save, "Save", 4, "The save every new player starts from.", :needs => :from_save, :group => "Starting point"),
        Field.new(:mods, :mods, "Mods", 5, "The mods of the world: listed, required to enter or essential. Enter picks them.", :group => "Game data"),
        Field.new(:mismatch, :check, "Allow data mismatch", 6, "Ticked: games with other data are warned. Unticked: kept out. Fixed once created.", :group => "Game data"),
        Field.new(:description, :area, "What the world is about", 7, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => DESCRIPTION_LINES, :group => "Description"),
        Field.new(:confirm, :button, "Create the world", 8, "Creates the world. You enter it from the list."),
      ]
      new("Create a new world", fields, :name => "", :password => "", :seats => DEFAULT_SEATS.to_s, :hidden => false, :from_save => false, :save => nil, :choose => false, :description => "", :mods => "", :mismatch => false)
    end

    # The form that changes a world, for its creator or an admin: what may change after it was made.
    #
    # @param listed [Directory::ListedWorld] The world in the directory.
    # @param own [Boolean] Whether the player made the world, and so may replace its game data.
    # @return [Form] The form, filled in as the world is.
    def self.edit(listed, own = false)
      fields = [
        Field.new(:seats, :number, "Max Players", 0, "Players in the world at once, #{MIN_SEATS} to #{MAX_SEATS}.", :max_chars => MAX_SEATS.to_s.size, :allowed => /\A\d\z/, :group => "World"),
        Field.new(:mods, :mods, "Mods", 1, "The mods of the world: listed, required to enter or essential. Enter picks them.", :group => "Game data"),
        Field.new(:description, :area, "What the world is about", 3, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => DESCRIPTION_LINES, :group => "Description"),
        Field.new(:confirm, :button, "Save the changes", 4, "Changes the world for everyone."),
      ]
      fields.insert(2, Field.new(:data, :button, "Update current data scan", 2, "Scans your game's data as it is now and makes it the world's, such as after a mod update.", :group => "Game data")) if own
      new("Edit #{listed.name}", fields, :seats => listed.seats.to_s, :mods => listed.mods.to_s, :description => listed.description.to_s)
    end

    # The form of the name the others see.
    #
    # @param name [String] The name as it is, "" for none.
    # @return [Form] The form, filled in with the name.
    def self.rename(name)
      fields = [
        Field.new(:name, :text, "Your name", 0, "The name the others see. Without one, your name on Discord.", :max_chars => MAX_NAME_CHARS, :group => "Player"),
        Field.new(:confirm, :button, "Use this name", 1, "Keeps the name for every world."),
      ]
      new("Your name", fields, :name => name)
    end

    # The form that adds a hidden world to the list by its id.
    #
    # @return [Form] The form, empty.
    def self.join
      fields = [
        Field.new(:id, :id, "World id", 0, "The id the world's creator copied for you. Ctrl+V pastes it.", :max_chars => 32, :allowed => /\A[0-9a-f]\z/i, :group => "World"),
        Field.new(:confirm, :button, "Add the world", 1, "Adds the world to your list, where you enter it like any other."),
      ]
      new("Add a hidden world", fields, :id => "")
    end

    # What the form is called.
    attr_reader :title

    # The fields, in the order the cursor visits them.
    attr_reader :fields

    # The key of the text box being typed into, nil while none is.
    attr_accessor :editing

    # The editor of the text box being typed into, nil while none is.
    attr_accessor :edit

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
        tidy.empty? && !field.optional ? [text, "The #{field.label.downcase} cannot be empty."] : [tidy, nil]
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

  # The mods of a world as the mod picker shows them: every mod the Patch folder holds, each
  # unlisted, listed, required or essential, then the mods added by name, which this game lacks.
  class ModPick
    # How a mod can be named, in the order the picker offers them.
    STATES = [:unlisted, :listed, :required, :essential]

    # The mark in front of a mod's name for each state it is named in.
    MARKS = { :listed => "", :required => "!", :essential => "?" }

    # A mod of the picker.
    #
    # @!attribute name [String] Its name, the script's file name for an installed one.
    # @!attribute state [Symbol] One of STATES.
    # @!attribute installed [Boolean] Whether the Patch folder holds it.
    Entry = Struct.new(:name, :state, :installed)

    # The mods, the installed ones first.
    attr_reader :entries

    # Reads the mods a world names into the player's installed ones; a named mod the player lacks
    # follows them as added.
    #
    # @param text [String, nil] The mods as written, see MGQ_MpWorld.mods_of.
    # @param installed [Array<String>] The installed mods' names, see MGQ_MpWorld.installed_mod_names.
    def initialize(text, installed)
      @entries = installed.map { |name| Entry.new(name, :unlisted, true) }
      required = MGQ_MpWorld.required_mods(text)
      essential = MGQ_MpWorld.essential_mods(text)

      MGQ_MpWorld.mods_of(text).each do |name|
        state = required.include?(name) ? :required : (essential.include?(name) ? :essential : :listed)
        entry = find(name)
        entry ? entry.state = state : @entries.push(Entry.new(name, state, false))
      end
    end

    # Writes the mods named, the way a world keeps them.
    #
    # @return [String] Each named mod with its mark, separated by semicolons.
    def text
      @entries.reject { |entry| entry.state == :unlisted }.map { |entry| "#{MARKS[entry.state]}#{entry.name}" }.join("; ")
    end

    # Names a mod another way. An added mod unlisted stays in the picker, but out of the text.
    #
    # @param index [Integer] The mod's index in entries.
    # @param state [Symbol] One of STATES.
    # @return [String, nil] Why it cannot, nil when it was done.
    def set(index, state)
      entry = @entries[index]
      before = entry.state
      entry.state = state
      return too_long(entry, before) if text.size > MAX_MODS_CHARS

      nil
    end

    # Takes a mod added by name out of the picker. An installed mod stays, since the Patch folder
    # holds it.
    #
    # @param index [Integer] The mod's index in entries.
    # @return [Boolean] Whether it was taken out.
    def remove(index)
      return false if @entries[index].installed

      @entries.delete_at(index)
      true
    end

    # Lists an unlisted mod, or unlists a named one.
    #
    # @param index [Integer] The mod's index in entries.
    # @return [String, nil] Why it cannot, nil when it was done.
    def toggle(index)
      set(index, @entries[index].state == :unlisted ? :listed : :unlisted)
    end

    # Makes a mod required or essential, or only listed again when it is so already.
    #
    # @param index [Integer] The mod's index in entries.
    # @param state [Symbol] :required or :essential.
    # @return [String, nil] Why it cannot, nil when it was done.
    def mark(index, state)
      set(index, @entries[index].state == state ? :listed : state)
    end

    # Tells whether every installed mod is named.
    #
    # @return [Boolean] Whether it is; also when none is installed.
    def all_listed?
      @entries.all? { |entry| !entry.installed || entry.state != :unlisted }
    end

    # Lists every unlisted installed mod, in order, until the text would grow too long.
    #
    # @return [String, nil] Why the rest could not be listed, nil when all were.
    def list_all
      @entries.each_index do |index|
        next unless @entries[index].installed && @entries[index].state == :unlisted

        error = set(index, :listed)
        return error if error
      end
      nil
    end

    # Unlists every installed mod; the mods added by name stay.
    #
    # @return [nil] Nothing, since unlisting always fits.
    def unlist_all
      @entries.each { |entry| entry.state = :unlisted if entry.installed }
      nil
    end

    # Adds a mod the player lacks by its name, listed.
    #
    # @param name [String] The name as typed.
    # @return [String, nil] Why it cannot, nil when it was added.
    def add(name)
      name = name.to_s.strip.sub(/\A[!?]\s*/, "")
      return "A mod's name cannot be empty." if name.empty?
      return "A mod's name cannot hold a semicolon." if name.include?(";")
      return "#{find(name).name} is in the list already." if find(name)

      @entries.push(Entry.new(name, :listed, false))
      return nil if text.size <= MAX_MODS_CHARS

      @entries.pop
      "The mods may take #{MAX_MODS_CHARS} characters at most."
    end

    # Finds a mod by its name, whatever its case, spaces, underscores and hyphens.
    #
    # @param name [String] The name.
    # @return [Entry, nil] The mod, nil when the picker has none of that name.
    def find(name)
      key = MGQ_MpWorld.mod_key(name)
      @entries.find { |entry| MGQ_MpWorld.mod_key(entry.name) == key }
    end

    private

    # Puts a mod's state back, since the text grew too long with the new one.
    #
    # @param entry [Entry] The mod.
    # @param state [Symbol] Its state before.
    # @return [String] Why the change was refused.
    def too_long(entry, state)
      entry.state = state
      "The mods may take #{MAX_MODS_CHARS} characters at most."
    end
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Before the title screen starts, a world the game came back from closes.
  MGQ_MpHooks.before(Scene_Title, :start, "world") { MGQ_MpWorld.on_title_start }

  # After the title screen's update, a new game starts in a world the world screen opened, and the
  # update notice shows.
  MGQ_MpHooks.after(Scene_Title, :update, "world") do
    MGQ_MpWorld.on_title_update(self) unless scene_changing?
    # The first title screen lists its commands before the update check answers, so the world
    # screen's command is greyed out only by listing them again.
    @command_window.refresh if MGQ_MpWorld::UpdateNotice.refresh
  end

  # A world's new game that asked something first has started once the game sets it up.
  MGQ_MpHooks.around(DataManager.singleton_class, :setup_new_game) do |_manager, _args, original|
    MGQ_MpWorld.new_game_started
    original.call
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
