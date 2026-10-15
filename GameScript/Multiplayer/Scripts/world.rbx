#----------------------------------------------------------------
#  world.rbx
#
#  Changelog:
#      Paulinchen  2026-10-15: Passed a new world's options to the DLL in one number
#      Paulinchen  2026-10-14: Gave a Raid World a shared save in every build, ticked as for a Classic world
#      Paulinchen  2026-10-13: Wrote the game data's fingerprint to GameData.ini at each start for the World Admin tool
#                            - Added a Classic world's raid bosses to the forms, the list and world.ini
#                            - Added a Raid World's squad rules to the forms, the list and world.ini
#                            - Set a Raid World's squad rules in a form of their own behind a button
#      Paulinchen  2026-10-12: Read the title screen's commands through MGQ_MpGame
#                            - Kept the favourites and the added hidden worlds in Player.ini, moving the old files into it
#                            - Left an unreadable world.ini as it is
#      Paulinchen  2026-10-11: Took the featured worlds' gold and the Raid Worlds' red from the shared style
#                            - Told whether a world's password is known
#      Paulinchen  2026-10-10: Let a development build give a Raid World a shared save
#                            - Put the parked mods back only once the updater started
#                            - Listed the worlds the directory no longer has after the others
#      Paulinchen  2026-10-09: Added Turn off other mods to the forms and the list
#                            - Put the new world's Raid-only and Classic-only fields on one row
#                            - Brought the parked mods back on the title screen and before the update, and noted the world entered
#                            - Held a new game or a Discord invite while the title screen restarts for the parked mods
#                            - Added a Raid World's difficulty to the forms, the list and world.ini
#                            - Greyed out the new world's starting point for a Raid World
#      Paulinchen  2026-10-08: Added the world's type, Classic or Raid, and a Raid World's companion sharing
#                            - Showed Raid Worlds in red above every other world
#                            - Added raid? and companion_sharing
#                            - Put the new world's starting point into its World panel
#                            - Let a form's field depend on any other field, and gave a switch its own label width
#                            - Added Shared Mod Settings to the create and edit forms
#                            - Closed with Numpad 0 through MGQ_MpUi.cancel?
#                            - Told whether the world stays open on the title screen for its new game
#                            - Logged the mod settings a new world starts with
#                            - Offered to update and install from the Multiplayer command once a newer release is out
#                            - Opened the world screen when the game started again after the update
#                            - Kept the game open under Wine or Proton, telling how to update by hand
#                            - Offered the update for a Discord invite into a world in an outdated game
#                            - Let each caller claim the directory action it starts
#                            - Read how the world list stands without its worlds
#      Paulinchen  2026-10-07: Registered the title screen hooks through core_hooks.rbx
#                            - Cached the worlds on this PC and the favourites until one changes
#                            - Named the DLL's exports alone
#                            - Added a form's switch between several outcomes
#                            - Logged entering and leaving worlds, the directory's requests and list, and the system saves
#      Paulinchen  2026-10-06: Built the form of a world's password
#                            - Asked a scene directly whether it changes
#                            - Called mp_dir_edit with as many arguments as its signature names
#                            - Took an empty player name while Discord knows theirs, and gave each text box its own empty reason
#                            - Removed missing_mods
#                            - Took Discord invites into a world
#                            - Opened a world's lock with its world code, and told the directory's id of a code
#                            - Left the world once the player backed out of its new game
#                            - Added the form of the player's name
#                            - Left Allow data mismatch unticked in a new world's form
#                            - Kept a mod added by name in the mod picker when unlisted
#                            - Listed the installed mods for the mod picker, and took up to 300 characters of mods
#                            - Sent a world's mod settings on their own
#                            - Read and sent a world's mod hashes and mod settings from its creator
#                            - Found a required mod's script in the Patch folder, and read the folder anew when asked
#      Paulinchen  2026-10-04: Showed the update notice in a message box
#                            - Greyed out the title command once the update check answers, and kept an outdated game out of worlds
#                            - Kept only the 50 hidden worlds added last
#                            - Removed Form#add
#                            - Renamed from mp_world.rbx
#                            - Let the creator describe a world, name its mods and keep out games with other data
#                            - Told a game's data from another's by its database entries and maps
#                            - Kept the editor of the text box being typed into with its form
#                            - Took a mod marked with an exclamation mark as required
#                            - Took a mod marked with a question mark as essential
#                            - Let a world's creator replace its game data
#                            - Told a changed world from the same one read again
#                            - Marked a world as a favourite as its creator makes it, and took descriptions of up to 1000 characters
#                            - Split the mods a world needs at each semicolon, and said create where a text said make
#                            - Added a hidden world to the list by its id
#                            - Let the creator or an admin change a world's Max Players, mods and description
#                            - Shortened the fields' hints
#                            - Grouped the forms' fields, renamed From my save to Shared save and Players choose their start to Player's choice
#      Paulinchen  2026-10-03: Reached the game's private fields and methods through MGQ_MpGame
#                            - Moved the text screen into world_text.rbx and the world screen into world_screen.rbx
#                            - Logged through MGQ_MpLog
#                            - Put the player's own system save and Save folder back when a world's system save cannot be loaded
#      Paulinchen  2026-10-02: Told how many players a world seats, from its code
#                            - Offered to copy a world's latest save into the player's own game
#                            - Made worlds without a password
#                            - Showed the featured worlds in gold after the favourites
#                            - Followed the title screen's start and update through core_hooks.rbx
#                            - Put the Save folder back in one place as a world closes
#                            - Added Players choose to the new world's form
#      Paulinchen  2026-10-01: Said that the relay's admins see hidden worlds too
#      Paulinchen  2026-09-30: Let the relay's admins see every world, hidden ones too, and delete any
#                            - Moved into Patch/Multiplayer/Scripts as world.rbx
#                            - Named the mod Monster Girl Quest! Online in the update notice
#                            - Greyed out the title command and showed a notice once a newer release is out
#                            - Let the creator pick one of their saves as a new world's starting save
#                            - Made and joined worlds through forms on the world screen, and added hidden worlds by id
#      Paulinchen  2026-09-29: Listed the relay's worlds with their players, favourites first, with a password asked once
#                            - Let the creator delete a world or remove a player, and connected to a world while it is open
#                            - Created
#
#----------------------------------------------------------------

# Worlds: lasting places several players play in together, entered through Multiplayer on the
# title screen. The relay's world directory lists every public world with its players, and hidden
# ones only for their players and the relay's admins; others add a hidden world to their list by
# its id. An admin may delete any world, and the admins' featured worlds show in gold. A world's
# password, if it has one, is asked once, after which this game remembers the world. Each world
# keeps its own saves and its own system save (Library, medals, system switches, affection) in
# Patch/Multiplayer/Worlds/<id>, so playing in a world never touches the player's own saves. A new
# world's players start at the beginning, from one of its creator's saves, or where each of them
# chooses (world_save_distribution.rbx). A world's details show what its creator wrote about it and
# the mods it needs, and whether the player's game data has the same entries as the creator's; a
# game that differs is warned, or kept out when the creator said so. A world is Classic, where each
# party plays its own story, or a Raid World, where the whole world plays one; its creator picks
# the type once, and Raid Worlds show in red above the other worlds the directory lists.
#
# It must never interrupt the game, so every entry point rescues.
module MGQ_MpWorld
  # Turns worlds off without uninstalling them.
  ENABLED = true

  # The title screen's command that opens the world screen.
  COMMAND_NAME = "Multiplayer"

  # The environment variable Update.ps1 sets for the game it starts again after an update that
  # the title screen began, which then opens the world screen.
  OPEN_AFTER_UPDATE = "MGQMP_OPEN_WORLDS"

  # Folder of the worlds on this PC, inside the mod folder.
  WORLDS_DIR = "Patch/Multiplayer/Worlds"

  # The folder the game loads its mods' scripts from.
  PATCH_DIR = "Patch"

  # What the settings of the favourite worlds in Player.ini start with, before a world's id.
  FAVOURITE_SETTING = "favourite."

  # What the settings of the hidden worlds the player added to their list by their ids start with
  # in Player.ini, before a world's id.
  ADDED_SETTING = "added."

  # The files in the mod folder that kept the favourites and the hidden worlds added before
  # Player.ini did, with what their settings start with there.
  OLD_LIST_FILES = { "Favourites.ini" => FAVOURITE_SETTING, "Added.ini" => ADDED_SETTING }

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

  # Lines of the description the create form shows at once for a Raid World, whose shared save takes
  # a row of its own.
  RAID_DESCRIPTION_LINES = 2

  # A world's id, which joins a hidden world.
  WORLD_ID = /\A[0-9a-f]{32}\z/

  # Colour of the featured worlds, which the relay's admins make, the style's gold.
  FEATURED_COLOR = MGQ_MpUi::Style::GOLD

  # Colour of the Raid Worlds, the style's bad color, which wins over the featured worlds' gold.
  RAID_COLOR = MGQ_MpUi::Style::BAD

  # The type of a Classic world, where each party plays its own story, as the directory and
  # world.ini name it.
  CLASSIC = "classic"

  # The type of a Raid World, where the whole world plays one story, as the directory and world.ini
  # name it.
  RAID = "raid"

  # A world's types, in the order the new world's form offers them.
  TYPES = [CLASSIC, RAID]

  # How a Raid World shares companions, as the directory and world.ini name it, in the order the new
  # world's form offers it.
  SHARING = ["off", "story", "all"]

  # Each way of sharing companions of SHARING, as companion_sharing tells it.
  SHARING_SYMBOLS = { "off" => :off, "story" => :story, "all" => :all }

  # What the new world's form and the details call each way of sharing companions.
  SHARING_NAMES = ["Off", "Story companions", "Story + battle recruits"]

  # The difficulties a Raid World may set for every player, the game's own values of its
  # difficulty variable, in the order the forms offer them.
  DIFFICULTIES = [-2, -1, 0, 1, 2, 3, 4]

  # The names of DIFFICULTIES, as the game's own difficulty choice shows them.
  DIFFICULTY_NAMES = ["VERY EASY", "EASY", "NORMAL", "HARD", "VERY HARD", "HELL", "PARADOX"]

  # The difficulty the forms offer first, NORMAL.
  DEFAULT_DIFFICULTY = 0

  # The Formation size that keeps the game's own team size, in which nobody sits out.
  ORIGINAL_FORMATION = 0

  # What the forms and the details call ORIGINAL_FORMATION.
  ORIGINAL_FORMATION_NAME = "Original"

  # The Formation sizes a Raid World may set, the team every player keeps, in the order the forms
  # offer them.
  FORMATIONS = [ORIGINAL_FORMATION, 4, 5, 6, 7, 8]

  # The Frontline's places a Raid World may give each player's team, in regular fights and in raids,
  # in the order the forms offer them.
  FRONTS = [1, 2, 3, 4]

  # The squad rules of a Raid World that names none: Luka fixed, a team of four and one character
  # on the Frontline in regular fights and in raids.
  DEFAULT_SQUAD = { :luka => false, :formation => 4, :front => 1, :raid_front => 1 }.freeze

  # The export that tells a development build from a release.
  DEV_BUILD_EXPORT = 'mp_dev_build'

  # The buttons whose press, in a frame no key went down, tells a gamepad from the keyboard.
  #
  # Directions count by their first frame only, since an arrow key held down reports its
  # direction in later frames too.
  GAMEPAD_BUTTONS = [:C, :B, :A, :UP, :DOWN, :LEFT, :RIGHT]

  # Reports whether the path wraps can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each wrap
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the wraps are in place already.
  def self.hookable?
    !(defined?(Bitmap) && Bitmap.method_defined?(:mgq_mp_world_initialize))
  end

  # Tells whether worlds can be used.
  #
  # @return [Boolean] Whether worlds are on, the mod's DLL is installed, and no newer
  #   release is out.
  def self.available?
    ENABLED && MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated?
  end

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
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

  # Tells whether the DLL is a development build, which a bug report names.
  #
  # @return [Boolean] Whether it is; false when the DLL cannot tell.
  def self.dev_build?
    @dev_build = MGQ_Multiplayer::Link.function(DEV_BUILD_EXPORT).call == 1 if @dev_build.nil?
    @dev_build
  rescue => e
    log("asking the DLL whether it is a development build failed: #{e.class}: #{e.message}")
    @dev_build = false
  end

  # Tells whether the open world is a Raid World, the one question every script asks.
  #
  # @return [Boolean] Whether it is; false while no world is open.
  def self.raid?
    !@world.nil? && @world.raid?
  end

  # Tells how the open Raid World shares companions.
  #
  # @return [Symbol] :off, :story (its story companions) or :all (its story companions and battle
  #   recruits); :off outside Raid Worlds.
  def self.companion_sharing
    raid? ? @world.companion_sharing : :off
  end

  # Tells the difficulty the open Raid World sets for every player.
  #
  # @return [Integer, nil] One of DIFFICULTIES; nil outside Raid Worlds and for a Raid World that
  #   sets none, whose players keep their own.
  def self.difficulty
    raid? ? @world.difficulty : nil
  end

  # Takes the difficulty the open Raid World's creator or an admin changed it to, as the relay
  # tells every game in it, and keeps it in world.ini.
  #
  # @param value [Integer] The difficulty.
  # @return [Boolean] Whether the open world is a Raid World that took it.
  def self.take_difficulty(value)
    return false unless raid? && DIFFICULTIES.include?(value)

    @world.difficulty = value
    @world.write
    true
  end

  # Names a difficulty as the game's own difficulty choice does.
  #
  # @param value [Integer, nil] The difficulty.
  # @return [String, nil] The name, nil for no difficulty.
  def self.difficulty_name(value)
    index = DIFFICULTIES.index(value)
    index ? DIFFICULTY_NAMES[index] : nil
  end

  # Reads a difficulty as world.ini or the list writes it.
  #
  # @param text [String, nil] The text.
  # @return [Integer, nil] One of DIFFICULTIES, nil for none or another text.
  def self.difficulty_of(text)
    value = text.to_s =~ /\A-?\d\z/ ? text.to_i : nil
    DIFFICULTIES.include?(value) ? value : nil
  end

  # Tells the squad rules the open Raid World sets for every player's team.
  #
  # @return [Hash, nil] :luka (whether Luka may leave the team), :formation (one of FORMATIONS),
  #   :front and :raid_front (the Frontline's places in regular fights and in raids, each one of
  #   FRONTS); DEFAULT_SQUAD for a Raid World that names none; nil outside Raid Worlds.
  def self.squad
    raid? ? (@world.squad || DEFAULT_SQUAD).dup : nil
  end

  # Takes the squad rules the open Raid World's creator or an admin changed, as the relay tells
  # every game in it, and keeps them in world.ini.
  #
  # @param squad [Hash] The rules, as squad tells them.
  # @return [Boolean] Whether the open world is a Raid World that took them.
  def self.take_squad(squad)
    valid = squad.is_a?(Hash) ? squad_of(squad_text(squad)) : nil
    return false unless raid? && valid

    @world.squad = valid
    @world.write
    true
  end

  # Reads squad rules as world.ini, the list and the relay write them: Luka (1 when he may leave
  # the team, else 0), the Formation size, the Frontline in regular fights and in raids, each
  # separated by a space.
  #
  # @param text [String, nil] The text, such as "0 4 1 1".
  # @return [Hash, nil] The rules, as squad tells them; nil for an empty text or one with a value
  #   out of its range.
  def self.squad_of(text)
    parts = text.to_s.split(" ")
    return nil unless parts.size == 4 && parts.all? { |part| part =~ /\A\d+\z/ }

    luka, formation, front, raid_front = parts.map { |part| part.to_i }
    return nil unless luka <= 1 && FORMATIONS.include?(formation) && FRONTS.include?(front) && FRONTS.include?(raid_front)

    { :luka => luka == 1, :formation => formation, :front => front, :raid_front => raid_front }
  end

  # Writes squad rules the way squad_of reads them.
  #
  # @param squad [Hash] The rules, as squad tells them.
  # @return [String] The text, such as "0 4 1 1".
  def self.squad_text(squad)
    [squad[:luka] ? 1 : 0, squad[:formation].to_i, squad[:front].to_i, squad[:raid_front].to_i].join(" ")
  end

  # Names a Formation size for texts.
  #
  # @param value [Integer] One of FORMATIONS.
  # @return [String] ORIGINAL_FORMATION_NAME, or the size as text.
  def self.formation_name(value)
    value.to_i == ORIGINAL_FORMATION ? ORIGINAL_FORMATION_NAME : value.to_i.to_s
  end

  # Tells squad rules in a few words, as the creator learns them after a change.
  #
  # @param squad [Hash] The rules, as squad tells them.
  # @return [String] The text, such as "Formation 4, Frontline 1 | 1, Luka fixed", the Frontline in
  #   regular fights before the one in raids.
  def self.squad_summary(squad)
    "Formation #{formation_name(squad[:formation])}, Frontline #{squad[:front]} | #{squad[:raid_front]}, Luka #{squad[:luka] ? 'replaceable' : 'fixed'}"
  end

  # Tells whether the open world is a Classic world whose story bosses fight as raid bosses of their
  # tier, see battles_raid_tiers.rbx.
  #
  # @return [Boolean] Whether it is; false while no world is open and in a Raid World.
  def self.raid_bosses?
    open? && !raid? && @world.raid_bosses ? true : false
  end

  # Takes whether the open Classic world fights raid bosses, as the relay tells every game in it
  # after its creator or an admin changed it, and keeps it in world.ini.
  #
  # @param on [Boolean] Whether it does.
  # @return [Boolean] Whether the open world is a Classic world that took it.
  def self.take_raid_bosses(on)
    return false unless open? && !raid?

    @world.raid_bosses = on ? true : false
    @world.write
    true
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

  # Shortens a long id for the log, which tells worlds apart well enough by its start.
  #
  # @param id [String, nil] The id.
  # @return [String] Its first 12 characters, "none" for nil.
  def self.short(id)
    id.nil? ? "none" : id.to_s[0, 12]
  end

  # Names a save as the log does.
  #
  # @param index [Integer, String] The save's index as DataManager takes it, a String for an autosave.
  # @return [String] Such as "save 3" or "autosave 01".
  def self.save_name(index)
    index.is_a?(Integer) ? "save #{index + 1}" : "autosave #{index}"
  end

  # Tells whether Discord told the player's name, now or in an earlier session, which an empty
  # chosen name falls back to.
  #
  # @return [Boolean] Whether it did.
  def self.discord_name?
    player = MGQ_Multiplayer::Player
    !MGQ_Multiplayer::Discord.player_name.to_s.empty? || !player.setting(player::DISCORD_NAME).to_s.empty?
  rescue => e
    log("reading the Discord name failed: #{e.class}: #{e.message}")
    false
  end

  # Enters a world from the world screen: its latest save when it has one, a new game otherwise,
  # which the title screen starts once the world screen closed.
  #
  # @param world [World] The world.
  # @param scene [Scene_MpWorlds] The world screen.
  # @return [String, nil] Why the world could not be entered, nil when it was.
  def self.start(world, scene)
    unless available?
      log("not entering world #{world.id}: worlds are off, the DLL is missing or the mod is outdated")
      return MGQ_Multiplayer::UPDATE_MESSAGE
    end

    enter(world)
    index = world.latest_save

    unless index
      log("world #{world.id} has no save here: starting a new game in it")
      @pending = :new_game
      scene.return_scene
      return nil
    end

    unless DataManager.load_game(index)
      leave("its #{save_name(index)} could not be loaded")
      return "The latest save of #{world.name} could not be loaded."
    end

    log("loaded #{save_name(index)} of world #{world.id}")
    # Scene_Load finishes the game's own loads, so the map starts exactly as after Continue.
    Scene_Load.new.on_load_success
    nil
  rescue => e
    leave("entering failed")
    log("could not enter a world: #{e.class}: #{e.message}")
    "The world could not be entered."
  end

  # Opens a world: from now on the game's saves and system save are the world's, and the game
  # holds a seat in the world's room.
  #
  # @param world [World] The world.
  def self.enter(world)
    leave("another world opens")
    Dir.mkdir(world.save_folder) unless File.directory?(world.save_folder)
    System.enter(world.save_folder)
    @world = world
    world.played!
    Link.open(world.code)
    MGQ_MpModParking.entered if defined?(MGQ_MpModParking)
    log("entered world #{world.id} (#{world.name}, directory #{short(world.directory_id)}, #{world.seats} seats)")
  end

  # Closes the open world, leaving its room and putting the player's own system save back.
  #
  # @param reason [String] Why, for the log.
  def self.leave(reason = "closed")
    return unless @world

    Link.close
    System.leave
    log("left world #{@world.id} (#{@world.name}): #{reason}")
    @world = nil
  rescue => e
    @world = nil
    log("could not leave the world cleanly: #{e.class}: #{e.message}")
  end

  # Closes the open world once the game went back to the title screen, unless the world screen
  # sent it there to start a new game in the world; the mods it had parked then come back. Called
  # as the title screen starts.
  def self.on_title_start
    if @pending
      log("kept world #{@world.id} open on the title screen: its new game starts there") if @world
    else
      left_world = !@world.nil?
      leave("the game went back to the title screen")
      MGQ_MpModParking.on_title_start(left_world) if defined?(MGQ_MpModParking)
    end
  end

  # Tells whether the world stays open on the title screen, where its new game starts.
  #
  # @return [Boolean] Whether it does.
  def self.new_game_pending?
    !@pending.nil?
  end

  # Starts a new game in the world the world screen opened, or opens the world screen for a
  # Discord invite. Called by the title screen every frame while nothing else runs.
  #
  # The title screen's own command starts it, so everything the game and other mods do for a
  # new game happens as usual.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    return watch_new_game(scene) if @pending == :starting
    return if UpdateOffer.shown? || (defined?(MGQ_MpModParking) && MGQ_MpModParking.title_busy?) || open_after_update(scene)
    return Invite.on_title_update(scene) unless @pending == :new_game

    @pending = nil
    log("new game in world #{@world.id}") if @world
    scene.command_new_game
    # New Game may ask something first and leave the title screen only after the answer.
    return if scene.scene_changing?

    @pending = :starting
    log("New Game asks something first, waiting for the answer")
  rescue => e
    @pending = nil
    leave("the new game could not start")
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
    leave("the player backed out of its new game")
  end

  # Notes that the world's new game started. Called as the game sets a new game up.
  def self.new_game_started
    return unless @pending == :starting

    @pending = nil
    log("the new game of world #{@world.id} started after its question") if @world
  end

  # Adds the world screen's command to the title screen, below Continue.
  #
  # @param window [Window_TitleCommand] The title screen's commands.
  def self.add_title_command(window)
    return unless MGQ_Multiplayer.available?

    list = MGQ_MpGame.get(window, :list)
    entry = { :name => COMMAND_NAME, :symbol => :mgq_mp_world, :enabled => true, :ext => nil }
    continue_at = list.index { |command| command[:symbol] == :continue }
    continue_at ? list.insert(continue_at + 1, entry) : list.push(entry)
    log_once(:title_command, "title command added")
  rescue => e
    log("title command failed: #{e.class}: #{e.message}")
  end

  # Opens the world screen from the title screen's command, or offers the update once a newer
  # release is out.
  #
  # @param scene [Scene_Title] The title screen.
  def self.open_world_screen(scene)
    return UpdateOffer.show(scene) if MGQ_Multiplayer.outdated?

    MGQ_MpGame.call(scene, :close_command_window)
    SceneManager.call(Scene_MpWorlds)
  end

  # Offers the update on the title screen once a newer release is out, as picking Multiplayer
  # does, for what would otherwise open the world screen on its own: a Discord invite, or the
  # entry again after a restart for a world's mods.
  #
  # @param scene [Scene_Title] The title screen.
  def self.offer_update(scene)
    return if UpdateOffer.shown?

    commands = MGQ_MpGame.get(scene, :command_window)
    # Picking Multiplayer deactivates the title's commands; the box gives them back as it closes.
    commands.deactivate if commands && !commands.disposed?
    UpdateOffer.show(scene)
  end

  # Opens the world screen once, when Update.ps1 started the game again after an update the title
  # screen began.
  #
  # @param scene [Scene_Title] The title screen.
  # @return [Boolean] Whether it opened.
  def self.open_after_update(scene)
    return false unless MGQ_Multiplayer.available? && ENV.delete(OPEN_AFTER_UPDATE)

    log("the game started again after its update: opening the world screen")
    open_world_screen(scene)
    true
  end

  # A message box that offers the update once the player picks Multiplayer while a newer release
  # is out: the DLL starts Update.bat, which waits for the game to close, updates the mod and
  # starts the game again in the world screen. The box holds the buttons while it shows.
  module UpdateOffer
    # The box's title, the newer version filled in.
    TITLE = "Monster Girl Quest! Online %s is out"

    # What the box offers.
    TEXT = "This is an older version, which cannot play online. Update and install closes the game, " \
           "updates the mod and starts the game again in the Multiplayer menu."

    # The hint at the bottom of the box while it offers the update.
    HINT = "Enter: update and install     Esc or Numpad 0: back"

    # What the box says when the updater could not start.
    FAILED_TEXT = "The updater could not start. Close the game and run Patch\\Multiplayer\\Update.bat to update."

    # What the box says under Wine or Proton, where the updater cannot run.
    WINE_TEXT = "Updating from the game needs Windows. Download the latest release and extract it over the game folder."

    # The hint at the bottom of the box once the updater could not start.
    FAILED_HINT = "Enter, Esc, Numpad 0 or a click: close"

    # Shows the box and takes the buttons from the title menu, which deactivated itself as the
    # player picked Multiplayer.
    #
    # @param scene [Scene_Title] The title screen.
    def self.show(scene)
      @scene = scene
      @failed = false
      @box ||= Sprite_MpMessageBox.new
      @box.show(title, TEXT, HINT)
      MGQ_MpWorld.log("update to #{MGQ_Multiplayer.newer_version} offered")
      MGQ_Multiplayer::Capture.start(:update_offer)
      # Windows keeps a click until it is asked for, so one from before the box would close it.
      MGQ_Multiplayer::Mouse.clicked?
    end

    # Reports whether the box shows.
    #
    # @return [Boolean] Whether it does.
    def self.shown?
      !@box.nil? && @box.visible
    end

    # Starts the update on confirm and closes the box on cancel; once the updater could not start,
    # confirm and a click close it too. Called every update of the title screen.
    def self.update
      return unless shown?

      capture = MGQ_Multiplayer::Capture
      # The mouse is asked every frame, so a click in a frame a key closed the box never counts later.
      clicked = MGQ_Multiplayer::Mouse.clicked?
      confirmed = capture.trigger?(:C)
      return update_and_install if confirmed && !@failed

      close if confirmed || MGQ_MpUi.cancel? || (clicked && @failed)
    end

    # Takes the box off the screen. Called when the title screen ends.
    def self.hide
      return unless @box

      MGQ_Multiplayer::Capture.stop(:update_offer)
      @box.dispose
      @box = nil
    end

    # Has the DLL start the updater and closes the game, or says that the updater could not start,
    # or cannot run under Wine. Parked mods come back once the updater started, which waits for this
    # game to close and then starts it again; an updater that did not start leaves them parked.
    def self.update_and_install
      started = MGQ_Multiplayer::Link.function('mp_update_game').call
      if started == 1
        MGQ_MpModParking.restore_for_update if defined?(MGQ_MpModParking)
        Sound.play_ok
        MGQ_MpWorld.log("closing the game for the update to #{MGQ_Multiplayer.newer_version}")
        return SceneManager.exit
      end

      Sound.play_buzzer
      MGQ_MpWorld.log(started == 2 ? "the updater cannot run under Wine" : "the updater could not start")
      @failed = true
      @box.show(title, started == 2 ? WINE_TEXT : FAILED_TEXT, FAILED_HINT)
    end

    # Hides the box and gives the buttons back to the title menu.
    def self.close
      Sound.play_cancel
      MGQ_MpWorld.log("update offer closed by the player")
      @box.visible = false
      MGQ_Multiplayer::Capture.stop(:update_offer)
      commands = MGQ_MpGame.get(@scene, :command_window)
      commands.activate if commands && !commands.disposed?
    end

    # The box's title.
    #
    # @return [String] The title, the newer version filled in.
    def self.title
      format(TITLE, MGQ_Multiplayer.newer_version)
    end
  end

  # Builds what the world screen lists: the directory's worlds, and the worlds on this PC the
  # directory no longer has, those it still has first, Raid Worlds first among them, then favourites,
  # then the featured ones, then those played last, then by name.
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

    entries.sort_by { |entry| [entry.gone ? 1 : 0, entry.raid? ? 0 : 1, entry.favourite ? 0 : 1, entry.featured? ? 0 : 1, -(entry.local ? entry.local.played_at.to_i : 0), entry.name.downcase] }
  end

  # A world as the world screen lists it: the directory's, this PC's folder of it, or both.
  #
  # @!attribute id [String, nil] The directory's id of the world, nil for a world on this PC whose world.ini names none.
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

    # Tells whether the world is a Raid World: as the directory lists it, or as world.ini keeps it
    # once the directory no longer lists it.
    #
    # @return [Boolean] Whether it is.
    def raid?
      listed ? listed.raid? : (!local.nil? && local.raid?)
    end

    # Tells whether the directory lists the world as one without a password.
    #
    # @return [Boolean] Whether it does.
    def open?
      !listed.nil? && listed.open
    end

    # Tells whether the world's password is known: this PC's folder of the world holds the world
    # code the relay handed out when the password was typed once, which entering reads instead
    # of asking for the password again. True for a world without a password too, once entered.
    #
    # World.read drops a folder without its code, so a folder listed here holds it.
    #
    # @return [Boolean] Whether it is.
    def password_known?
      !local.nil?
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
      length = MGQ_Multiplayer::Link.function('mp_world_id').call(code + "\0", buffer, buffer.size)
      length > 0 ? buffer[0, length] : nil
    end

    # Tells the directory's id of a world by its code.
    #
    # @param code [String] The world code.
    # @return [String, nil] The id, nil when the text is no world code.
    def self.directory_id(code)
      buffer = "\0" * 64
      length = MGQ_Multiplayer::Link.function('mp_world_directory_id').call(code + "\0", buffer, buffer.size)
      length > 0 ? buffer[0, length] : nil
    end

    # Takes a seat in a world's room, again whenever the connection breaks, until the world is closed.
    #
    # @param code [String] The world code.
    def self.open(code)
      MGQ_Multiplayer::Player.share
      MGQ_MpWorld.log("could not open the world's connection") unless MGQ_Multiplayer::Link.function('mp_world_open').call(code + "\0") == 1
    end

    # Leaves the world's room.
    def self.close
      MGQ_Multiplayer::Link.function('mp_world_close').call
    end

    # Puts a text on the clipboard.
    #
    # @param text [String] The text.
    # @return [Boolean] Whether the clipboard holds it.
    def self.copy(text)
      MGQ_Multiplayer::Link.function('mp_copy_text').call(text + "\0") == 1
    end
  end

  # Discord invites into a world: the Discord mod hands over the world code an invite carries, and
  # the world screen enters that world with it instead of asking for its password.
  module Invite
    # What the notification box says when an invite comes in during a game.
    LATER_TEXT = "Discord invite taken: the title screen opens the world."

    # Takes an invite the player accepted in Discord, if it is into a world.
    #
    # @param code [String] The invite's join secret.
    # @return [Boolean] Whether it was into a world, which leaves it to the world screen.
    def self.receive(code)
      id = Link.directory_id(code)
      return false unless id

      if MGQ_MpWorld.open? && MGQ_MpWorld.world.directory_id == id
        MGQ_MpWorld.log("ignored an invite into world #{MGQ_MpWorld.short(id)}, which is open already")
      else
        @pending = [id, code]
        MGQ_MpWorld.log("took an invite into world #{MGQ_MpWorld.short(id)}")
        MGQ_MpNotices.message(:world_invite, LATER_TEXT) if defined?(MGQ_MpNotices) && !SceneManager.scene.is_a?(Scene_Title)
      end
      true
    end

    # Opens the world screen for the invite taken last, or offers the update in its place once a
    # newer release is out. Called by the title screen every frame while nothing else runs.
    #
    # @param scene [Scene_Title] The title screen.
    def self.on_title_update(scene)
      return unless @pending

      if MGQ_MpWorld::ENABLED && MGQ_Multiplayer.available? && MGQ_Multiplayer.outdated?
        MGQ_MpWorld.log("not opening the world screen for the invite into world #{MGQ_MpWorld.short(@pending[0])}: the mod is outdated")
        @pending = nil
        return MGQ_MpWorld.offer_update(scene)
      end
      return unless MGQ_MpWorld.available?

      MGQ_MpWorld.log("opening the world screen for the invite into world #{MGQ_MpWorld.short(@pending[0])}")
      SceneManager.call(Scene_MpWorlds)
    end

    # Takes the invite for the world screen, once.
    #
    # @return [Array, nil] The world's directory id and code, nil without an invite.
    def self.take
      pending = @pending
      @pending = nil
      pending
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

    # The file in the mod folder the fingerprint is written to at each start, from which the World
    # Admin tool reads an installation's game data: its "fingerprint" and when it was "written", in
    # seconds since 1970.
    FILE = "#{MGQ_Multiplayer::MOD_DIR}\\GameData.ini"

    # Finds the fingerprint of this game's data, once per session.
    #
    # It reads whether an entry has a name, never the name itself, so a translated game matches
    # the untranslated one as long as both name the same entries.
    #
    # @return [String] FORMAT, then a checksum per part; empty when the data could not be read.
    def self.fingerprint
      return @fingerprint if @fingerprint

      @fingerprint = "#{FORMAT}:" + ids.map { |list| format("%08x", Zlib.crc32(list.join(","))) }.join(".")
      MGQ_MpWorld.log("this game's data: #{@fingerprint}")
      @fingerprint
    rescue => e
      MGQ_MpWorld.log_once(:fingerprint, "reading the game data failed: #{e.class}: #{e.message}")
      ""
    end

    # Writes the fingerprint to FILE, once per session, as the title screen first opens, after the
    # mods changed the game's data.
    def self.write_file
      return if @written

      @written = true
      text = fingerprint
      return if text.empty?

      MGQ_Multiplayer::Ini.write(FILE, "fingerprint" => text, "written" => Time.now.to_i)
    rescue => e
      MGQ_MpWorld.log("writing #{FILE} failed: #{e.class}: #{e.message}")
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
    # @!attribute type [String] Its type, one of TYPES; CLASSIC when the list names none.
    # @!attribute share [String] How a Raid World shares companions, one of SHARING; "off" when the list names none.
    # @!attribute difficulty [Integer, nil] The difficulty a Raid World sets for every player, one of DIFFICULTIES; nil when it sets none.
    # @!attribute other_mods_off [Boolean] Whether it turns off every mod it does not name, see MGQ_MpModParking.
    # @!attribute squad [Hash, nil] The squad rules a Raid World sets for every player's team, see MGQ_MpWorld.squad; nil when it names none.
    # @!attribute raid_bosses [Boolean] Whether a Classic world's story bosses fight as raid bosses, see MGQ_MpWorld.raid_bosses?.
    ListedWorld = Struct.new(:id, :seats, :online, :creator_id, :active, :creator_name, :name, :start, :members, :hidden, :choose, :open, :featured, :strict, :data, :mods, :description, :mod_hashes, :settings,
                             :type, :share, :difficulty, :other_mods_off, :squad, :raid_bosses) do
      # Tells whether the world is a Raid World.
      #
      # @return [Boolean] Whether it is.
      def raid?
        type == RAID
      end
    end

    # A player of a world.
    #
    # @!attribute id [String] The player's id.
    # @!attribute online [Boolean] Whether the player is in the world now.
    # @!attribute name [String] The player's name.
    Member = Struct.new(:id, :online, :name)

    # Bytes the DLL may write the list into at first. A larger list asks for a larger buffer.
    LIST_SIZE = 65_536

    # The bits of mp_dir_create's options: the world is hidden, new players choose where to start,
    # only games with the same data may enter.
    HIDDEN_OPTION = 1
    CHOOSE_OPTION = 2
    STRICT_OPTION = 4

    # Fetches the list again, with the hidden worlds the player added to it.
    def self.refresh
      MGQ_Multiplayer::Link.function('mp_dir_watch').call(Added.all.join(",") + "\0")
      MGQ_Multiplayer::Link.function('mp_dir_refresh').call
    end

    # Looks a world up by its id alone; the action tells its name.
    #
    # @param id [String] The world's id.
    # @return [Boolean] Whether the action started.
    def self.find(id)
      started(MGQ_Multiplayer::Link.function('mp_dir_find').call(id + "\0") == 1, "find world #{MGQ_MpWorld.short(id)}")
    end

    # Logs a request sent to the directory, or that it could not start.
    #
    # @param started [Boolean] Whether it started.
    # @param what [String] The request, without secrets.
    # @return [Boolean] started.
    def self.started(started, what)
      MGQ_MpWorld.log(started ? "directory request sent: #{what}" : "directory request could not start: #{what}")
      started
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
          worlds.push(ListedWorld.new(fields[1], fields[2].to_i, fields[3].to_i, fields[4], fields[5].to_i, fields[6].to_s, fields[7].to_s, fields[8] || "none", [], fields[9] == "1", fields[10] == "1", fields[11] == "1", fields[12] == "1", fields[13] == "1", fields[14].to_s, fields[15].to_s, fields[16].to_s, fields[17].to_s, fields[18].to_s,
                                     fields[19].to_s.empty? ? CLASSIC : fields[19], fields[20].to_s.empty? ? SHARING[0] : fields[20], fields[19] == RAID ? MGQ_MpWorld.difficulty_of(fields[21]) : nil,
                                     fields[22].to_s.empty? ? fields[19] == RAID : fields[22] == "1", fields[19] == RAID ? MGQ_MpWorld.squad_of(fields[23]) : nil,
                                     fields[19] != RAID && fields[24] == "1"))
        when "member"
          worlds.last.members.push(Member.new(fields[1], fields[2] == "1", fields[3].to_s)) if worlds.last
        end
      end

      result = [state["state"] || "idle", state["error"], worlds, state["admin"] == "1"]
      log_list(result)
      result
    end

    # Logs how the list stands whenever that changed.
    #
    # @param result [Array] What list returns.
    def self.log_list(result)
      state, error, worlds, admin = result
      # The list is fetched again every few seconds, which is no news.
      return if state == "loading" && @logged_list

      seen = [state, error, worlds.map { |world| [world.id, world.name, world.online, world.seats, world.members.size] }, admin]
      return if seen == @logged_list

      @logged_list = seen
      described = worlds.map { |world| "#{world.name} (#{MGQ_MpWorld.short(world.id)}, #{world.online}/#{world.seats} online)" }
      MGQ_MpWorld.log("list #{state}#{error ? " (#{error})" : ''}#{admin ? ', as an admin' : ''}: #{worlds.size} world(s)#{described.empty? ? '' : ': ' + described.join(', ')}")
    rescue
    end

    # Makes a world, locked with its password, with the starting save new players get, if there is one.
    #
    # @param name [String] The world's name.
    # @param password [String] The password, empty for none.
    # @param seats [Integer] How many players it seats at once.
    # @param hidden [Boolean] Whether the list leaves it out for everyone but its players and the relay's admins.
    # @param choose [Boolean] Whether each new player chooses where to start.
    # @param start [String] The starting save's files, see MGQ_MpSaveDistribution.text_of; empty for none.
    # @param about [Hash] Whichever of :description, :mods, :data (the creator's game data), :strict (true when only games with the same data may enter), :mod_hashes, :settings,
    #   :type (one of TYPES, CLASSIC when left out), :share (one of SHARING, "off" when left out), :difficulty (one of DIFFICULTIES, NORMAL when left out),
    #   :squad (the squad rules, see MGQ_MpWorld.squad, DEFAULT_SQUAD when left out), :raid_bosses (whether a Classic world fights raid bosses, false when left out) and
    #   :other_mods_off (whether it turns off every mod it does not name, by its type when left out) apply;
    #   a Raid World takes no player's choice, but may take a starting save.
    # @return [Boolean] Whether the action started.
    def self.create(name, password, seats, hidden, choose, start, about = {})
      MGQ_Multiplayer::Player.share
      type = about[:type] || CLASSIC
      raid = type == RAID
      share = raid ? about[:share] || SHARING[0] : SHARING[0]
      difficulty = raid ? about[:difficulty] || DEFAULT_DIFFICULTY : DEFAULT_DIFFICULTY
      squad = raid ? MGQ_MpWorld.squad_text(about[:squad] || DEFAULT_SQUAD) : ""
      raid_bosses = !raid && about[:raid_bosses] ? true : false
      other_mods_off = about[:other_mods_off].nil? ? raid : about[:other_mods_off]
      choose = false if raid
      options = (hidden ? HIDDEN_OPTION : 0) | (choose ? CHOOSE_OPTION : 0) | (about[:strict] ? STRICT_OPTION : 0)
      sent = MGQ_Multiplayer::Link.function('mp_dir_create').call(name + "\0", password + "\0", seats, options, start + "\0",
                                                                                  about[:description].to_s + "\0", about[:mods].to_s + "\0", about[:data].to_s + "\0",
                                                                                  about[:mod_hashes].to_s + "\0", about[:settings].to_s + "\0", type + "\0", share + "\0", difficulty,
                                                                                  other_mods_off ? 1 : 0, squad + "\0", raid ? -1 : (raid_bosses ? 1 : 0)) == 1
      files = start.empty? ? "no starting save" : "a starting save of #{start.split("\n").size} file(s)"
      started(sent, "create #{name}: #{raid ? "raid, sharing #{share}, difficulty #{MGQ_MpWorld.difficulty_name(difficulty)}, squad \"#{squad}\"" : "classic#{raid_bosses ? ', raid bosses' : ''}"}, " \
                    "#{other_mods_off ? 'other mods off' : 'other mods allowed'}, " \
                    "#{seats} seats, #{password.empty? ? 'no password' : 'a password'}, #{hidden ? 'hidden' : 'public'}, " \
                    "#{choose ? "player's choice" : 'no choice'}, #{files}, mods \"#{about[:mods]}\", #{about[:strict] ? 'strict' : 'mismatch allowed'}, " \
                    "data #{about[:data].to_s.empty? ? 'unknown' : about[:data]}, description of #{about[:description].to_s.size} chars, creator hashes \"#{about[:mod_hashes]}\", " \
                    "#{about[:settings].to_s.empty? ? "each player's own mod settings" : "mod settings \"#{about[:settings]}\""}")
    end

    # Opens a world's lock with its password; the action tells the world's name, its starting save,
    # whether new players choose where to start, the mods it needs and which games may enter too, so
    # a hidden world is joined by its id alone.
    #
    # @param id [String] The world's id.
    # @param password [String] The password.
    # @return [Boolean] Whether the action started.
    def self.unlock(id, password)
      sent = MGQ_Multiplayer::Link.function('mp_dir_unlock').call(id + "\0", password + "\0") == 1
      started(sent, "unlock world #{MGQ_MpWorld.short(id)} #{password.empty? ? 'without a password' : 'with a password'}")
    end

    # Opens a world's lock with its world code instead of its password, as a Discord invite hands
    # it over; the action tells the same as unlock.
    #
    # @param code [String] The world code.
    # @return [Boolean] Whether the action started.
    def self.unlock_code(code)
      started(MGQ_Multiplayer::Link.function('mp_dir_unlock_code').call(code + "\0") == 1, "unlock a world with an invite")
    end

    # Changes a world's seats, description, mods, a Raid World's difficulty and squad rules, a
    # Classic world's raid bosses and whether it turns other mods off, which its creator or an admin
    # may, and for its creator the hashes of its required mods outside the catalog.
    #
    # @param id [String] The world.
    # @param seats [Integer] How many players it seats at once.
    # @param description [String] What it is about, empty for nothing.
    # @param mods [String] The mods it needs, empty for none.
    # @param mod_hashes [String, nil] The creator's mod hashes, nil to leave them, as an admin must.
    # @param difficulty [Integer, nil] A Raid World's difficulty, one of DIFFICULTIES; nil to leave it, as for every Classic world.
    # @param other_mods_off [Boolean, nil] Whether it turns off every mod it does not name; nil to leave it.
    # @param squad [Hash, nil] A Raid World's squad rules, see MGQ_MpWorld.squad; nil to leave them, as for every Classic world.
    # @param raid_bosses [Boolean, nil] Whether a Classic world fights raid bosses; nil to leave it, as for every Raid World.
    # @return [Boolean] Whether the action started.
    def self.edit(id, seats, description, mods, mod_hashes = nil, difficulty = nil, other_mods_off = nil, squad = nil, raid_bosses = nil)
      MGQ_Multiplayer::Player.share
      squad_text = squad ? MGQ_MpWorld.squad_text(squad) : ""
      sent = MGQ_Multiplayer::Link.function('mp_dir_edit').call(id + "\0", seats, description + "\0", mods + "\0", mod_hashes.to_s + "\0", mod_hashes ? 1 : 0,
                                                                                difficulty.to_i, difficulty ? 1 : 0, other_mods_off ? 1 : 0, other_mods_off.nil? ? 0 : 1, squad_text + "\0",
                                                                                raid_bosses.nil? ? -1 : (raid_bosses ? 1 : 0)) == 1
      started(sent, "edit world #{MGQ_MpWorld.short(id)}: #{seats} seats, mods \"#{mods}\", description of #{description.size} chars, creator hashes #{mod_hashes ? "\"#{mod_hashes}\"" : 'kept'}" \
                    "#{difficulty ? ", difficulty #{MGQ_MpWorld.difficulty_name(difficulty)}" : ''}#{squad ? ", squad \"#{squad_text}\"" : ''}" \
                    "#{raid_bosses.nil? ? '' : ", raid bosses #{raid_bosses ? 'on' : 'off'}"}#{other_mods_off.nil? ? '' : ", other mods #{other_mods_off ? 'off' : 'allowed'}"}")
    end

    # Replaces a world's mod settings, which its creator or an admin may.
    #
    # @param id [String] The world.
    # @param settings [String] "key=type:value" pairs separated by semicolons.
    # @return [Boolean] Whether the action started.
    def self.set_settings(id, settings)
      MGQ_Multiplayer::Player.share
      sent = MGQ_Multiplayer::Link.function('mp_dir_set_settings').call(id + "\0", settings + "\0") == 1
      started(sent, "set the mod settings of world #{MGQ_MpWorld.short(id)}: \"#{settings}\"")
    end

    # Replaces a world's game data with this game's as it is now, which only its creator may.
    #
    # @param id [String] The world.
    # @return [Boolean] Whether the action started; not while this game's data cannot be read.
    def self.set_data(id)
      MGQ_Multiplayer::Player.share
      sent = MGQ_Multiplayer::Link.function('mp_dir_set_data').call(id + "\0", GameData.fingerprint + "\0") == 1
      started(sent, "set the game data of world #{MGQ_MpWorld.short(id)} to #{GameData.fingerprint}")
    end

    # Deletes a world for everyone.
    #
    # @param id [String] The world.
    # @return [Boolean] Whether the action started.
    def self.delete(id)
      MGQ_Multiplayer::Player.share
      started(MGQ_Multiplayer::Link.function('mp_dir_delete').call(id + "\0") == 1, "delete world #{MGQ_MpWorld.short(id)}")
    end

    # Removes a player from a world and keeps them out.
    #
    # @param id [String] The world.
    # @param target [String] The player's id.
    # @return [Boolean] Whether the action started.
    def self.ban(id, target)
      MGQ_Multiplayer::Player.share
      sent = MGQ_Multiplayer::Link.function('mp_dir_ban').call(id + "\0", target + "\0") == 1
      started(sent, "remove player #{MGQ_MpWorld.short(target)} from world #{MGQ_MpWorld.short(id)}")
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
      MGQ_Multiplayer::Link.function('mp_dir_clear').call
    end

    # Notes that the action just started belongs to its caller, since the DLL keeps one action's
    # answer at a time for the world screen and the world's mod settings alike.
    #
    # @return [Integer] The ticket that names the action.
    def self.claim
      @claimed = @claimed.to_i + 1
      @released = false
      @claimed
    end

    # Tells whether the action started last is the one a ticket names, whose answer is its caller's.
    #
    # @param ticket [Integer, nil] The ticket.
    # @return [Boolean] Whether it is.
    def self.mine?(ticket)
      !ticket.nil? && ticket == @claimed
    end

    # Gives up on the answer of an action, which the next one may then drop.
    #
    # @param ticket [Integer, nil] The action's ticket.
    def self.release(ticket)
      @released = true if mine?(ticket)
    end

    # Tells whether an action may start without dropping an answer its caller still waits for: none
    # ran, or the last one ended and was given up on, whose answer this forgets.
    #
    # @return [Boolean] Whether one may.
    def self.free?
      state = action["state"]
      return true if state == "idle"
      return false if state == "busy" || !@released

      clear
      true
    end

    # Reads how the list stands, without its worlds.
    #
    # @return [String] "idle", "loading", "ready" or "failed".
    def self.list_state
      MGQ_Multiplayer::Link.parse(MGQ_Multiplayer::Link.read('mp_dir_list', LIST_SIZE))["state"] || "idle"
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
    unless @installed
      @installed = Dir.glob("#{PATCH_DIR}/**/*.rb").map { |path| mod_key(File.basename(path)) }
      log("the Patch folder holds #{@installed.size} script(s): #{@installed.join(', ')}")
    end
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

  # Turns a mod's name or its script's file name into what the two are compared by.
  #
  # @param name [String] The name.
  # @return [String] The name in lower case, without ".rb", spaces, underscores and hyphens.
  def self.mod_key(name)
    name.to_s.downcase.sub(/\.rb\z/, "").gsub(/[\s_\-]/, "")
  end

  # The favourites and hidden worlds added that the files before Player.ini kept, moved into it once.
  module OldLists
    # Moves the entries of OLD_LIST_FILES into Player.ini, a setting it holds already winning, then
    # deletes the files; tried again at most every Player::RETRY_SECONDS until it worked.
    #
    # Nothing is moved or deleted while any of the files or Player.ini cannot be read, so no entry
    # is lost.
    def self.merge
      return if @merged
      return if @tried_at && Time.now - @tried_at < MGQ_Multiplayer::Player::RETRY_SECONDS

      files = OLD_LIST_FILES.keys.select { |file| File.exist?(MGQ_Multiplayer.path(file)) }
      if files.empty?
        @merged = true
        return
      end

      entries = entries_of(files)
      return later("#{files.join(' or ')} could not be read") unless entries
      return later("Player.ini could not be read") unless MGQ_Multiplayer::Player.readable?

      fresh = entries.reject { |key, _| MGQ_Multiplayer::Player.setting(key) }
      return later("Player.ini could not be written") unless MGQ_Multiplayer::Player.change(fresh)

      @merged = true
      MGQ_MpWorld.log("moved the #{entries.size} entries of #{files.join(' and ')} into Player.ini, #{entries.size - fresh.size} of which it held already")
      files.each { |file| delete(file) }
    rescue => e
      later("#{e.class}: #{e.message}")
    end

    # Reads the old files' entries as Player.ini's settings.
    #
    # @param files [Array<String>] The files there are, of OLD_LIST_FILES.
    # @return [Hash, nil] The values by setting, nil when a file could not be read.
    def self.entries_of(files)
      entries = {}
      files.each do |file|
        values = MGQ_Multiplayer::Ini.load(MGQ_Multiplayer.path(file), !@tried_at.nil?)
        return nil unless values

        values.each { |id, value| entries[OLD_LIST_FILES[file] + id] = value }
      end
      entries
    end

    # Notes that the move must wait, logged once until it worked.
    #
    # @param reason [String] Why it waits.
    def self.later(reason)
      MGQ_MpWorld.log("did not move the favourites and hidden worlds into Player.ini yet: #{reason}") unless @tried_at
      @tried_at = Time.now
      nil
    end

    # Deletes an old file whose entries Player.ini holds now.
    #
    # @param file [String] The file, of OLD_LIST_FILES.
    def self.delete(file)
      File.delete(MGQ_Multiplayer.path(file))
      MGQ_MpWorld.log("deleted #{file}")
    rescue => e
      MGQ_MpWorld.log("could not delete #{file}, so the next start moves its entries again: #{e.class}: #{e.message}")
    end
  end

  # The hidden worlds the player added to their list by their ids, which the relay lists for
  # whoever names them, kept in Player.ini.
  module Added
    # Most worlds kept, as many as the relay lists by their ids for one player.
    MAX = 50

    # Lists the worlds added.
    #
    # @return [Array<String>] Their directory ids, the one added last at the end.
    def self.all
      OldLists.merge
      MGQ_Multiplayer::Player.keys_under(ADDED_SETTING)
    end

    # Adds a world, and forgets those added longest ago beyond MAX.
    #
    # The ids of deleted worlds are never listed again and so never removed by hand; without the
    # limit they would crowd the newest ones out of what the relay lists.
    #
    # @param id [String] The world's directory id.
    def self.add(id)
      ids = all - [id] + [id]
      dropped = ids.size > MAX ? ids[0, ids.size - MAX] : []
      changes = {}
      dropped.each { |old| changes[ADDED_SETTING + old] = nil }
      changes[ADDED_SETTING + id] = "1"
      return unless kept?(MGQ_Multiplayer::Player.change(changes), "add hidden world #{MGQ_MpWorld.short(id)} to the list")

      forgot = dropped.empty? ? "" : ", forgot the oldest: #{dropped.map { |old| MGQ_MpWorld.short(old) }.join(', ')}"
      MGQ_MpWorld.log("added hidden world #{MGQ_MpWorld.short(id)} to the list#{forgot}")
    end

    # Takes a world off the list again.
    #
    # @param id [String] The world's directory id.
    def self.remove(id)
      OldLists.merge
      return unless kept?(MGQ_Multiplayer::Player.forget(ADDED_SETTING + id), "remove hidden world #{MGQ_MpWorld.short(id)} from the list")

      MGQ_MpWorld.log("removed hidden world #{MGQ_MpWorld.short(id)} from the list")
    end

    # Logs a change of the list that Player.ini did not take.
    #
    # @param written [Boolean] Whether Player.ini was written.
    # @param what [String] The change, for the log.
    # @return [Boolean] Whether it was written.
    def self.kept?(written, what)
      MGQ_MpWorld.log("could not #{what}: Player.ini was not written") unless written
      written
    end
  end

  # The worlds the player marked as favourites, kept in Player.ini.
  module Favourites
    # Lists the favourites.
    #
    # @return [Array<String>] The directory ids of the favourite worlds.
    def self.all
      OldLists.merge
      MGQ_Multiplayer::Player.keys_under(FAVOURITE_SETTING)
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
    # @return [Boolean, nil] Whether it is a favourite now, nil when it stays as it was since Player.ini cannot be read.
    def self.toggle(id)
      OldLists.merge
      key = FAVOURITE_SETTING + id
      favourite = MGQ_Multiplayer::Player.setting(key).nil?
      MGQ_Multiplayer::Player.change(key => favourite ? "1" : nil)
      if MGQ_Multiplayer::Player.setting(key).nil? == favourite
        MGQ_MpWorld.log("world #{MGQ_MpWorld.short(id)} stays as it was: Player.ini cannot be read")
        return nil
      end

      MGQ_MpWorld.log("world #{MGQ_MpWorld.short(id)} #{favourite ? 'is a favourite now' : 'is no longer a favourite'}")
      favourite
    end
  end

  # A world on this PC: its folder in Patch/Multiplayer/Worlds, named by a hash of its code, with
  # world.ini (name, world code, directory id, type, how a Raid World shares companions, its
  # difficulty and squad rules, whether a Classic world fights raid bosses, when it was made and
  # last played) and the world's Save folder.
  class World
    # The file inside the world's folder that describes it.
    FILE = "world.ini"

    # What a world's folder is named.
    ID = /\A[0-9a-f]{12}\z/

    # Lists the worlds on this PC, read from their folders once until one is made, written or
    # deleted, since the world screen asks every few frames.
    #
    # @return [Array<World>] The worlds.
    def self.all
      @all ||= list
    end

    # Forgets the worlds read, so the next look reads their folders again.
    def self.forget
      @all = nil
    end

    # Reads the worlds on this PC from their folders.
    #
    # @return [Array<World>] The worlds.
    def self.list
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
      of(id, MGQ_Multiplayer::Ini.read("#{folder_of(id)}/#{FILE}"))
    end

    # Builds a world from what its world.ini says.
    #
    # @param id [String] The folder's id.
    # @param values [Hash] The values of its world.ini.
    # @return [World, nil] The world, nil when they hold no world code of the folder.
    def self.of(id, values)
      code = values["code"]
      code && Link.id_of(code) == id ? new(id, values) : nil
    end

    # Makes a world's folder, or finds the one there is, and describes the world in it.
    #
    # @param code [String] The world code.
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @param type [String, nil] Its type, one of TYPES; nil to keep what world.ini says.
    # @param share [String, nil] How a Raid World shares companions, one of SHARING; nil to keep what world.ini says.
    # @param difficulty [Integer, nil] A Raid World's difficulty, one of DIFFICULTIES; nil to keep what world.ini says.
    # @param squad [Hash, nil] A Raid World's squad rules, see MGQ_MpWorld.squad; nil to keep what world.ini says.
    # @param raid_bosses [Boolean, nil] Whether a Classic world fights raid bosses; nil to keep what world.ini says.
    # @return [World, nil] The world, nil when the text is no world code, the folder could not be
    #   made or its world.ini exists but could not be read, which is then left as it is.
    def self.found(code, name, directory_id, type = nil, share = nil, difficulty = nil, squad = nil, raid_bosses = nil)
      id = Link.id_of(code)
      unless id
        MGQ_MpWorld.log("no folder for world #{MGQ_MpWorld.short(directory_id)}: the relay's answer holds no world code")
        return nil
      end

      [WORLDS_DIR, folder_of(id)].each { |dir| Dir.mkdir(dir) unless File.directory?(dir) }
      values = MGQ_Multiplayer::Ini.load("#{folder_of(id)}/#{FILE}")
      unless values
        MGQ_MpWorld.log("left folder #{id} of world #{MGQ_MpWorld.short(directory_id)} as it is: its #{FILE} exists but could not be read")
        return nil
      end

      known = of(id, values)
      world = known || new(id, "code" => code, "created" => Time.now.to_i)
      world.describe(name, directory_id, nil, type, share, difficulty, squad, raid_bosses)
      written = world.write
      MGQ_MpWorld.log("#{known ? 'found' : 'made'} folder #{id} of world #{MGQ_MpWorld.short(directory_id)} (#{world.name})#{written ? '' : ', but world.ini could not be written'}")
      written ? world : nil
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

    # The world's id in the directory, nil when world.ini names none.
    attr_reader :directory_id

    # When the world was played last.
    attr_reader :played_at

    # The world's type, one of TYPES, nil when world.ini names none, which counts as Classic.
    attr_reader :type

    # How a Raid World shares companions, one of SHARING, nil when world.ini names none.
    attr_reader :share

    # The difficulty a Raid World sets for every player, one of DIFFICULTIES, nil when world.ini names none.
    attr_accessor :difficulty

    # The squad rules a Raid World sets for every player's team, see MGQ_MpWorld.squad, nil when
    # world.ini names none.
    attr_accessor :squad

    # Whether a Classic world's story bosses fight as raid bosses, see MGQ_MpWorld.raid_bosses?.
    attr_accessor :raid_bosses

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
      @type = values["type"]
      @share = values["share"]
      @difficulty = MGQ_MpWorld.difficulty_of(values["difficulty"])
      @squad = MGQ_MpWorld.squad_of(values["squad"])
      @raid_bosses = values["raid_bosses"].to_s == "1"
    end

    # Takes the world's name, directory id, seats, type, companion sharing, difficulty, squad rules and raid bosses, as the directory says them.
    #
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @param seats [Integer, nil] How many players it seats now, which its creator may change; nil to keep what the code tells.
    # @param type [String, nil] Its type, one of TYPES; nil to keep what world.ini says.
    # @param share [String, nil] How a Raid World shares companions, one of SHARING; nil to keep what world.ini says.
    # @param difficulty [Integer, nil] A Raid World's difficulty, one of DIFFICULTIES; nil to keep what world.ini says.
    # @param squad [Hash, nil] A Raid World's squad rules, see MGQ_MpWorld.squad; nil to keep what world.ini says.
    # @param raid_bosses [Boolean, nil] Whether a Classic world fights raid bosses; nil to keep what world.ini says.
    def describe(name, directory_id, seats = nil, type = nil, share = nil, difficulty = nil, squad = nil, raid_bosses = nil)
      @name = MGQ_Multiplayer.clean(name)
      @directory_id = directory_id
      @type = type if type
      @share = share if share
      @difficulty = difficulty if difficulty
      @squad = squad if squad
      @raid_bosses = raid_bosses ? true : false unless raid_bosses.nil?
      parts = @code.to_s.split(";")
      @code = (parts[0...-1] + [seats.to_s]).join(";") if seats && parts.size > 3 && parts.last =~ /\A\d+\z/
    end

    # The world's folder.
    #
    # @return [String] The folder, relative to the game's folder.
    def folder
      World.folder_of(@id)
    end

    # Tells whether the world is a Raid World, as world.ini keeps it.
    #
    # @return [Boolean] Whether it is.
    def raid?
      @type == RAID
    end

    # Tells how the world shares companions.
    #
    # @return [Symbol] :off, :story or :all; :off for a Classic world and for a value world.ini does not know.
    def companion_sharing
      raid? ? SHARING_SYMBOLS[@share] || :off : :off
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
      values["type"] = @type if @type
      values["share"] = @share if @share
      values["difficulty"] = @difficulty if @difficulty
      values["squad"] = MGQ_MpWorld.squad_text(@squad) if @squad
      values["raid_bosses"] = 1 if @raid_bosses
      values["played"] = @played_at.to_i if @played_at
      World.forget
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
      World.forget
      World.remove_tree(folder)
      MGQ_MpWorld.log("deleted folder #{@id} of world #{MGQ_MpWorld.short(@directory_id)} (#{@name}) with its saves")
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
      MGQ_MpWorld.log("saved the player's own system save and loaded the world's from #{folder}")
    rescue => e
      MGQ_MpWorld.log("the world's system save could not be loaded, the player's own is back: #{e.class}: #{e.message}")
      # Without this the game would go on in the world's folder with no world open, and the next
      # world would keep the half-loaded system save as the player's own.
      put_back
      raise
    end

    # Writes the world's system save and puts the player's own back.
    def self.leave
      return unless @own

      DataManager.save_system
      MGQ_MpWorld.log("saved the world's system save and put the player's own back")
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
    # What the lines at the top say on Shared Mod Settings.
    SHARED_HINT = "Ticked: every player plays with your mod options here. Unticked: each keeps their own."

    # What the lines at the top say on Turn off other mods.
    OTHER_MODS_HINT = "Ticked: mods the world does not name are off in it. Personal mods stay on."

    # What the lines at the top say on Turn off other mods in the edit form.
    EDIT_OTHER_MODS_HINT = "Ticked: mods the world does not name are off. Personal mods stay on. Players in it enter again."

    # What the lines at the top say on the world type.
    TYPE_HINT = "Classic: each party plays its own story. Raid: the whole world plays one. Fixed once created."

    # What the lines at the top say on Sharing companions.
    SHARING_HINT = "Raid only: companions everyone gets on reaching their level. Fixed once created."

    # What the lines at the top say on Raid Bosses.
    RAID_BOSSES_HINT = "Classic only: story bosses fight as raid bosses of their tier, far stronger. Changeable later."

    # What the lines at the top say on Raid Bosses in the edit form.
    EDIT_RAID_BOSSES_HINT = "Story bosses fight as raid bosses of their tier, far stronger, from each player's next boss fight."

    # What the lines at the top say on the difficulty.
    DIFFICULTY_HINT = "Every player of the world plays on it. You can change it later in the edit form."

    # What the lines at the top say on the difficulty in a Raid World's edit form.
    EDIT_DIFFICULTY_HINT = "Every player of the world plays on it, those in it now at once."

    # The edit form's first outcome of the difficulty for a Raid World that sets none, whose players
    # keep their own while it stays picked.
    PER_PLAYER = "Per player"

    # Width of the world type's label, narrower than a text box's, so the switch fits half a row.
    TYPE_LABEL_WIDTH = 70

    # Width of a Save label that shares its row, narrower than a text box's, so the save's name fits half a row.
    RAID_SAVE_LABEL_WIDTH = 40

    # Width of the squad rules' switch labels, narrower than a text box's, so Original fits half a row.
    SQUAD_LABEL_WIDTH = 80

    # What the button that opens the form of a Raid World's squad rules says.
    LIMITS_LABEL = "Set formation limits"

    # What the lines at the top say on the button of a Raid World's squad rules.
    LIMITS_HINT = "Luka, the team size and the Frontlines every player keeps. Changeable later too."

    # What the lines at the top say on the button that leaves the form of a Raid World's squad rules.
    DONE_HINT = "Back to the world's form. Cancel goes back too, keeping the limits."

    # What the lines at the top say on Luka Replaceable.
    LUKA_HINT = "Ticked: players may take Luka out of their team. Unticked: he always stays in it."

    # What the lines at the top say on the Formation size.
    FORMATION_HINT = "The team size every player keeps. Its last place sits out, except with Original, the game's own."

    # What the lines at the top say on the Frontline in regular fights.
    FRONT_HINT = "In front in regular fights, the rest on the Backline. With more players, each one's first fights."

    # What the lines at the top say on the Frontline in raids.
    RAID_FRONT_HINT = "In front in raid boss fights, the rest on the Backline. With more players, each one's first fights."

    # The outcomes of the Formation size's switch, one per FORMATIONS.
    FORMATION_NAMES = FORMATIONS.map { |value| MGQ_MpWorld.formation_name(value) }

    # The outcomes of the Frontline's switches, one per FRONTS.
    FRONT_NAMES = FRONTS.map { |value| value.to_s }

    # What the lines at the top say on a Raid World's Shared save.
    RAID_SAVE_HINT = "New players start from one of your saves, the world's story from its point. Fixed once created."

    # A field of a form: a text box (:text, :password, :number or :id), a box of several lines (:area), a checkbox (:check), a save
    # to choose (:save), the mods picked in the mod picker (:mods), a switch between several outcomes (:switch) or a button
    # (:button).
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

      # The checkbox that must be ticked for the field to be used, or a block called with the form that
      # tells whether it may, nil for neither.
      attr_reader :needs

      # Whether a text box may stay empty, or a save stay unchosen.
      attr_reader :optional

      # The heading of the panel it is in, nil for a field outside every panel.
      attr_reader :group

      # How many lines a box of several lines shows.
      attr_reader :lines

      # What the lines at the top of the world screen say while the cursor is on the field.
      attr_reader :hint

      # Tells whether a text box may stay empty right now, nil when only optional decides.
      attr_reader :empty_ok

      # Why a text box that must be filled in is refused while empty.
      attr_reader :empty_text

      # The outcomes a switch moves between, as shown.
      attr_reader :choices

      # Tells a switch's line below its outcome, such as what the outcome picked brings: called with
      # the form and the outcome's index, nil for no line.
      attr_reader :note

      # Width of a switch's or a save's label, nil for the width its window gives every label.
      attr_reader :label_width

      # A block called with the form that tells whether the field is part of it now, nil for always.
      attr_reader :shows

      # Creates a field.
      #
      # @param key [Symbol] What the form keeps its value under.
      # @param kind [Symbol] What kind of field it is.
      # @param label [String] What it is called.
      # @param row [Integer] The row it is on.
      # @param hint [String] What the lines at the top say while the cursor is on it.
      # @param options [Hash] Whichever of :side, :max_chars, :allowed, :needs (a key or a proc), :optional (also for a save), :group, :lines,
      #   :empty_ok (a proc), :empty_text, :choices, :note (a proc), :label_width and :shows (a proc) apply.
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
        @empty_ok = options[:empty_ok]
        @empty_text = options[:empty_text] || "This field cannot be empty."
        @choices = options[:choices] || []
        @note = options[:note]
        @label_width = options[:label_width]
        @shows = options[:shows]
      end

      # Tells the line below a switch's outcome.
      #
      # @param form [Form] The form, whose other fields the line may follow.
      # @return [String] The line, empty for none.
      def note_of(form)
        @note ? @note.call(form, form[@key].to_i).to_s : ""
      rescue
        ""
      end

      # Tells whether the text box may stay empty.
      #
      # @return [Boolean] Whether it may.
      def may_be_empty?
        @optional || (@empty_ok ? (@empty_ok.call ? true : false) : false)
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
        Field.new(:name, :text, "Name", 0, "The name everyone sees in the list.", :max_chars => MAX_NAME_CHARS, :group => "World", :empty_text => "The world needs a name."),
        Field.new(:password, :password, "Password", 1, "Typed once to enter the world. Left empty, anyone may enter.", :max_chars => MAX_PASSWORD_CHARS, :side => :left, :group => "World"),
        Field.new(:seats, :number, "Max Players", 1, "Players in the world at once, #{MIN_SEATS} to #{MAX_SEATS}.", :max_chars => MAX_SEATS.to_s.size, :allowed => /\A\d\z/, :side => :right, :group => "World"),
        Field.new(:hidden, :check, "Hidden", 2, "Only its players see it in the list. Others add it with its id.", :side => :left, :group => "World"),
        Field.new(:type, :switch, "World type", 2, TYPE_HINT, :side => :right, :group => "World", :choices => ["Classic", "Raid"], :label_width => TYPE_LABEL_WIDTH),
        # Raid only and Classic only, each shown for its type, so the form keeps to one page.
        Field.new(:share, :switch, "Sharing companions", 3, SHARING_HINT, :group => "World", :choices => SHARING_NAMES,
                  :shows => lambda { |form| form.type == RAID }),
        Field.new(:from_save, :check, "Shared save", 3, "Classic only: new players start from one of your saves. Fixed once created.", :side => :left, :group => "World",
                  :shows => lambda { |form| form.type == CLASSIC }),
        Field.new(:choose, :check, "Player's choice", 3, "Classic only: new players pick their start, the opening or a save. Fixed once created.", :side => :right, :group => "World",
                  :shows => lambda { |form| form.type == CLASSIC }),
        # A Classic world shares the row between its Save and Raid Bosses, so the form keeps to one page.
        Field.new(:save, :save, "Save", 4, "The save every new player starts from.", :side => :left, :group => "World", :label_width => RAID_SAVE_LABEL_WIDTH,
                  :needs => lambda { |form| form.from_save? }, :shows => lambda { |form| form.type == CLASSIC }),
        Field.new(:raid_bosses, :check, "Raid Bosses", 4, RAID_BOSSES_HINT, :side => :right, :group => "World", :shows => lambda { |form| form.type == CLASSIC }),
        # A Raid World's Shared save shares its row with the Difficulty and its Save with the button of
        # its squad rules, whose row comes off the description, so the form keeps to one page.
        Field.new(:from_save, :check, "Shared save", 4, RAID_SAVE_HINT, :side => :left, :group => "World",
                  :shows => lambda { |form| form.type == RAID }),
        Field.new(:difficulty, :switch, "Difficulty", 4, DIFFICULTY_HINT, :side => :right, :group => "World", :choices => DIFFICULTY_NAMES,
                  :label_width => TYPE_LABEL_WIDTH, :shows => lambda { |form| form.type == RAID }),
        Field.new(:save, :save, "Save", 5, "The save every new player starts from.", :side => :left, :group => "World", :label_width => RAID_SAVE_LABEL_WIDTH,
                  :needs => lambda { |form| form.from_save? }, :shows => lambda { |form| form.type == RAID }),
        limits_field(5, :right, lambda { |form| form.type == RAID }),
        Field.new(:mods, :mods, "Mods", 6, "The mods of the world: listed, required to enter or essential. Enter picks them.", :group => "Game data"),
        Field.new(:mismatch, :check, "Allow data mismatch", 7, "Ticked: games with other data are warned. Unticked: kept out. Fixed once created.", :side => :left, :group => "Game data"),
        Field.new(:shared, :check, "Shared Mod Settings", 7, SHARED_HINT, :side => :right, :group => "Game data"),
        Field.new(:other_mods_off, :check, "Turn off other mods", 8, OTHER_MODS_HINT, :group => "Game data"),
        # The row of a Raid World's Save comes off its description, so the form keeps to one page.
        Field.new(:description, :area, "What the world is about", 9, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => DESCRIPTION_LINES, :group => "Description",
                  :shows => lambda { |form| form.type != RAID }),
        Field.new(:description, :area, "What the world is about", 9, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => RAID_DESCRIPTION_LINES,
                  :group => "Description", :shows => lambda { |form| form.type == RAID }),
        Field.new(:confirm, :button, "Create the world", 10, "Creates the world. You enter it from the list."),
      ]
      new("Create a new world", fields, { :name => "", :password => "", :seats => DEFAULT_SEATS.to_s, :hidden => false, :type => 0, :share => 0, :from_save => false, :save => nil, :choose => false, :description => "", :mods => "",
                                          :mismatch => false, :shared => false, :difficulty => DIFFICULTIES.index(DEFAULT_DIFFICULTY), :other_mods_off => false, :raid_bosses => false }.merge(squad_values(DEFAULT_SQUAD)))
    end

    # The button of a Raid World's form that opens the form of its squad rules, see limits.
    #
    # @param row [Integer] Its row.
    # @param side [Symbol, nil] :left or :right when it shares the row, nil when it has the row alone.
    # @param shows [Proc, nil] The block that tells whether it is part of the form now, nil for always.
    # @return [Field] The button.
    def self.limits_field(row, side, shows = nil)
      Field.new(:limits, :button, LIMITS_LABEL, row, LIMITS_HINT, :side => side, :group => "World", :shows => shows)
    end

    # The fields of the form of a Raid World's squad rules, on three rows: Luka Replaceable beside the
    # Formation size, the Frontline in regular fights beside the one in raids, and the button back.
    #
    # @return [Array<Field>] The fields.
    def self.limits_fields
      [
        Field.new(:luka, :check, "Luka Replaceable", 0, LUKA_HINT, :side => :left, :group => "Team"),
        Field.new(:formation, :switch, "Formation Size", 0, FORMATION_HINT, :side => :right, :group => "Team", :choices => FORMATION_NAMES, :label_width => SQUAD_LABEL_WIDTH),
        Field.new(:front, :switch, "Frontline", 1, FRONT_HINT, :side => :left, :group => "Team", :choices => FRONT_NAMES, :label_width => SQUAD_LABEL_WIDTH),
        Field.new(:raid_front, :switch, "Raid Frontline", 1, RAID_FRONT_HINT, :side => :right, :group => "Team", :choices => FRONT_NAMES, :label_width => SQUAD_LABEL_WIDTH),
        Field.new(:done, :button, "Done", 2, DONE_HINT),
      ]
    end

    # What the squad rules' fields hold at first for squad rules.
    #
    # @param squad [Hash] The rules, see MGQ_MpWorld.squad.
    # @return [Hash] The values by the fields' keys.
    def self.squad_values(squad)
      { :luka => squad[:luka] ? true : false, :formation => FORMATIONS.index(squad[:formation]).to_i, :front => FRONTS.index(squad[:front]).to_i,
        :raid_front => FRONTS.index(squad[:raid_front]).to_i }
    end

    # The form that changes a world, for its creator or an admin: what may change after it was made.
    #
    # @param listed [Directory::ListedWorld] The world in the directory.
    # @param own [Boolean] Whether the player made the world, and so may replace its game data and
    #   choose whether it shares their mod settings.
    # @return [Form] The form, filled in as the world is; a Raid World's with its difficulty and the
    #   button of its squad rules below the seats, the difficulty first PER_PLAYER for one that sets none.
    def self.edit(listed, own = false)
      fields = [
        Field.new(:seats, :number, "Max Players", 0, "Players in the world at once, #{MIN_SEATS} to #{MAX_SEATS}.", :max_chars => MAX_SEATS.to_s.size, :allowed => /\A\d\z/, :group => "World"),
        Field.new(:mods, :mods, "Mods", 2, "The mods of the world: listed, required to enter or essential. Enter picks them.", :group => "Game data"),
        Field.new(:other_mods_off, :check, "Turn off other mods", 5, EDIT_OTHER_MODS_HINT, :group => "Game data"),
        Field.new(:description, :area, "What the world is about", 6, "Shown in the world's details. Optional.", :max_chars => MAX_DESCRIPTION_CHARS, :optional => true, :lines => DESCRIPTION_LINES, :group => "Description"),
        Field.new(:confirm, :button, "Save the changes", 7, "Changes the world for everyone."),
      ]
      if own
        fields.insert(2, Field.new(:data, :button, "Update current data scan", 3, "Scans your game's data as it is now and makes it the world's, such as after a mod update.", :group => "Game data"),
                         Field.new(:shared, :check, "Shared Mod Settings", 4, SHARED_HINT, :group => "Game data"))
      end
      choices = listed.difficulty.nil? ? [PER_PLAYER] + DIFFICULTY_NAMES : DIFFICULTY_NAMES
      if listed.type == RAID
        fields.insert(1, Field.new(:difficulty, :switch, "Difficulty", 1, EDIT_DIFFICULTY_HINT, :side => :left, :group => "World", :choices => choices, :label_width => TYPE_LABEL_WIDTH),
                      limits_field(1, :right))
      else
        fields.insert(1, Field.new(:raid_bosses, :check, "Raid Bosses", 1, EDIT_RAID_BOSSES_HINT, :group => "World"))
      end
      new("Edit #{listed.name}", fields, { :seats => listed.seats.to_s, :mods => listed.mods.to_s, :description => listed.description.to_s, :shared => MGQ_MpWorldMods.shared?(listed.settings),
                                           :difficulty => choices.index(MGQ_MpWorld.difficulty_name(listed.difficulty) || PER_PLAYER),
                                           :other_mods_off => listed.other_mods_off ? true : false, :raid_bosses => listed.raid_bosses ? true : false }.merge(squad_values(listed.squad || DEFAULT_SQUAD)))
    end

    # The form of the name the others see.
    #
    # @param name [String] The name as it is, "" for none.
    # @return [Form] The form, filled in with the name.
    def self.rename(name)
      fields = [
        Field.new(:name, :text, "Your name", 0, "The name the others see. Without one, your name on Discord.", :max_chars => MAX_NAME_CHARS, :group => "Player",
                  :empty_ok => lambda { MGQ_MpWorld.discord_name? }, :empty_text => "Type a name: Discord has not told yours yet."),
        Field.new(:confirm, :button, "Use this name", 1, "Keeps the name for every world."),
      ]
      new("Your name", fields, :name => name)
    end

    # The form of a world's password, which enters it.
    #
    # @param name [String] The world's name.
    # @return [Form] The form, empty.
    def self.password(name)
      fields = [
        Field.new(:password, :password, "Password", 0, "The password the world's creator gave you.", :max_chars => MAX_PASSWORD_CHARS, :group => "World"),
        Field.new(:confirm, :button, "Enter the world", 1, "Opens the world with the password."),
      ]
      new("Enter #{name}", fields, :password => "")
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

    # Lists the fields that are part of the form now, in the order the cursor visits them.
    #
    # @return [Array<Field>] The fields.
    def fields
      @fields.select { |field| field.shows.nil? || field.shows.call(self) }
    end

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

    # Tells whether a field can be used, which one whose checkbox is not ticked, or whose block says
    # no, cannot.
    #
    # @param field [Field] The field.
    # @return [Boolean] Whether it can.
    def enabled?(field)
      return true if field.needs.nil?
      return field.needs.call(self) ? true : false if field.needs.respond_to?(:call)

      @values[field.needs] == true
    end

    # Tells the world type the new world's form picks.
    #
    # @return [String] One of TYPES.
    def type
      TYPES[@values[:type].to_i] || CLASSIC
    end

    # Tells how the new world's form has a Raid World share companions.
    #
    # @return [String] One of SHARING; "off" for a Classic world.
    def share
      type == RAID ? SHARING[@values[:share].to_i] || SHARING[0] : SHARING[0]
    end

    # Tells the difficulty the form picks.
    #
    # @return [Integer, nil] One of DIFFICULTIES; nil for PER_PLAYER.
    def difficulty
      field = @fields.find { |candidate| candidate.key == :difficulty }
      name = field ? field.choices[@values[:difficulty].to_i] : nil
      index = DIFFICULTY_NAMES.index(name)
      return DIFFICULTIES[index] if index

      name == PER_PLAYER ? nil : DEFAULT_DIFFICULTY
    end

    # The form of the squad rules this form picks, which holds the same values, so whatever it
    # changes this form keeps.
    #
    # @return [Form] The form, the same one each time.
    def limits
      @limits ||= Form.new("Formation limits", Form.limits_fields, @values)
    end

    # Tells the squad rules the form picks.
    #
    # @return [Hash] The rules, see MGQ_MpWorld.squad.
    def squad
      { :luka => @values[:luka] == true, :formation => FORMATIONS[@values[:formation].to_i] || DEFAULT_SQUAD[:formation],
        :front => FRONTS[@values[:front].to_i] || DEFAULT_SQUAD[:front], :raid_front => FRONTS[@values[:raid_front].to_i] || DEFAULT_SQUAD[:raid_front] }
    end

    # Tells whether the new world's form has new players start from one of the creator's saves, with
    # Shared save ticked.
    #
    # @return [Boolean] Whether it does.
    def from_save?
      @values[:from_save] == true
    end

    # Tells whether the form has a Classic world's story bosses fight as raid bosses.
    #
    # @return [Boolean] Whether it does; false for a Raid World.
    def raid_bosses?
      type == CLASSIC && @values[:raid_bosses] == true
    end

    # Tells whether the new world's form lets each new player choose where to start, which only a
    # Classic world does.
    #
    # @return [Boolean] Whether it does.
    def choose?
      type == CLASSIC && @values[:choose] == true
    end

    # Moves a switch to its next or its previous outcome, round.
    #
    # @param field [Field] The switch.
    # @param step [Integer] 1 for the next outcome, -1 for the previous.
    # @return [Integer] The outcome's index now.
    def turn(field, step)
      count = [field.choices.size, 1].max
      @values[field.key] = (@values[field.key].to_i + step) % count
      follow_type if field.key == :type
      @values[field.key]
    end

    # Ticks a checkbox, or unticks it, which from then on keeps what the player chose.
    #
    # @param key [Symbol] The checkbox's key.
    # @return [Boolean] Whether it is ticked now.
    def tick(key)
      @ticked = (@ticked || []) | [key]
      @values[key] = !@values[key]
    end

    # Ticks Turn off other mods for a Raid World and unticks it for a Classic one, unless the player
    # ticked or unticked it themselves.
    def follow_type
      return if !@values.key?(:other_mods_off) || (@ticked || []).include?(:other_mods_off)

      @values[:other_mods_off] = type == RAID
    end

    # Tells whether the form turns off every mod the world does not name.
    #
    # @return [Boolean] Whether it does.
    def other_mods_off?
      @values[:other_mods_off] == true
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
        tidy.empty? && !field.may_be_empty? ? [text, field.empty_text] : [tidy, nil]
      end
    end

    # Finds the first field that keeps the form from being sent.
    #
    # @return [Array, nil] The field's index and why, nil when the form can be sent.
    def problem
      fields.each_with_index do |field, index|
        next unless enabled?(field)

        error = field.typed? ? check(field, @values[field.key])[1] : nil
        error ||= "Choose the save its players start from." if field.kind == :save && !field.optional && @values[field.key].nil?
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

  # As the title screen first opens, the game data for the World Admin tool.
  MGQ_MpHooks.after(Scene_Title, :start, "world") { MGQ_MpWorld::GameData.write_file }

  # After the title screen's update, a new game starts in a world the world screen opened, and the
  # update offer takes the buttons.
  MGQ_MpHooks.after(Scene_Title, :update, "world") do
    MGQ_MpWorld.on_title_update(self) unless scene_changing?
    MGQ_MpWorld::UpdateOffer.update
  end

  # A world's new game that asked something first has started once the game sets it up.
  MGQ_MpHooks.before(DataManager.singleton_class, :setup_new_game, "world") { MGQ_MpWorld.new_game_started }

  # The title screen's commands, Multiplayer below Continue, which opens the world screen.
  MGQ_MpHooks.after(Window_TitleCommand, :make_command_list, "world") { MGQ_MpWorld.add_title_command(self) }
  MGQ_MpHooks.after(Scene_Title, :create_command_window, "world") do
    commands = MGQ_MpGame.get(self, :command_window)
    commands.set_handler(:mgq_mp_world, lambda { MGQ_MpWorld.open_world_screen(self) }) if commands
  end

  # Before the title screen ends, the update offer goes off the screen.
  MGQ_MpHooks.before(Scene_Title, :terminate, "world") { MGQ_MpWorld::UpdateOffer.hide rescue nil }
rescue => e
  MGQ_MpWorld.log("title hooks FAILED: #{e.class}: #{e.message}")
end

# Game hooks of this script alone: the paths below the Save folder, which core_hooks.rbx cannot
# wrap, since they change what the game's methods get.

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
      #
      # @param args [Array] The arguments Bitmap.new takes.
      def initialize(*args)
        mgq_mp_world_initialize(*MGQ_MpWorld::Files.mapped(args))
      end
    end
  rescue => e
    MGQ_MpWorld.log("picture hook FAILED: #{e.class}: #{e.message}")
  end
end
