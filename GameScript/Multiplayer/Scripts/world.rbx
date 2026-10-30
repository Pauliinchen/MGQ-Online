#----------------------------------------------------------------
#  world.rbx
#
#  Changelog:
#      Paulinchen  2026-10-30: Carried a Discord invite taken during a game through the Mod Framework's restart
#                            - Asked the Mod Framework for the release to play in place of the update offer
#                            - Entered the game through the Mod Framework with the mods of the world's session right before its save loads or its New Game starts
#                            - Started the game again into the world screen once the player backed out of a world's New Game after entering
#                            - Dropped the parked mods
#                            - Left the title's Multiplayer command to the Mod Framework under it
#                            - Counted an entry of the game data by its note, features and effects, never its name
#      Paulinchen  2026-10-28: Closed the world's story before its room, so a world left for the title screen keeps its last writes
#                            - Dropped the invite as the title screen opens the world screen for it
#      Paulinchen  2026-10-23: Dropped the list's refresh, the favourites, the hidden worlds added and removed, the deleted saves and the clipboard copy the DLL's steps do now
#                            - Dropped the favourites, the hidden worlds added and removed, the deleted saves and the clipboard copy the DLL's steps do now
#                            - Dropped the directory requests and tickets the DLL's world screen requests left without a caller
#                            - Left opening a world's lock, reading its mods, its data update and the Discord invite's code to the DLL's steps into a world
#                            - Took the world screen's entries and the mod picker's labels and colours from the DLL's model
#                            - Dropped the list of the scripts every player has, which the DLL keeps
#                            - Left the directory's action tickets to the DLL
#                            - Left the world screen's forms to the DLL, keeping a form of this game alone for the story's choices and the bug report
#                            - Left the worlds on this PC, the world screen's entries, the favourites, the hidden worlds added, the Discord invite, the game data compared and the mod picker to the DLL
#                            - Read a world's mods text through the DLL and took what changed in the worlds once a frame
#                            - Asked the DLL for the seats, difficulties and squad rules a world may set, and for the seats its code tells
#                            - Asked the DLL for the mod keys and the scripts in Patch
#                            - Offered the update under Wine or Proton too, and named the release to install by hand with --version
#                            - Dropped the fallbacks for list fields the DLL always writes
#                            - Left the details of the world list, a new world and an edit to the DLL log
#                            - Deleted the switch that never turned worlds off
#      Paulinchen  2026-10-22: Read the mods of the opened world on their own and let a world name mods up to the relay's new limit
#                            - Offered a step back to an older release as the one to install
#      Paulinchen  2026-10-15: Handed keywords on through the wrapped File and Dir methods
#                            - Passed a new world's options to the DLL in one number
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
  # The title screen's command that opens the world screen.
  COMMAND_NAME = "Multiplayer"

  # Folder of the worlds on this PC, inside the mod folder.
  WORLDS_DIR = "Patch/Multiplayer/Worlds"

  # The folder the game loads its mods' scripts from.
  PATCH_DIR = "Patch"


  # Longest text that names the mods a world needs, as long as the relay takes, far above any real
  # list.
  MAX_MODS_CHARS = 16_000


  # The topic that lists the scripts in the Patch folder with their keys.
  INSTALLED_TOPIC = "mods.installed"

  # The topic that makes the keys of mods' names.
  KEYS_TOPIC = "mods.keys"

  # The topic that reads a world's mods as written.
  TEXT_TOPIC = "mods.text"

  # Mods texts mods_text keeps read before it forgets them all.
  MODS_TEXTS_KEPT = 256

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

  # How a Raid World shares companions, as the directory and world.ini name it, in the order the new
  # world's form offers it.
  SHARING = ["off", "story", "all"]

  # Each way of sharing companions of SHARING, as companion_sharing tells it.
  SHARING_SYMBOLS = { "off" => :off, "story" => :story, "all" => :all }

  # The topic that hands out the seats, difficulties, Formation sizes, Frontlines and squad rules a
  # world may set, and their defaults.
  RULES_TOPIC = "world.rules"

  # The topic that reads squad rules from their text.
  SQUAD_READ_TOPIC = "squad.read"

  # The topic that writes squad rules as their text.
  SQUAD_WRITE_TOPIC = "squad.write"

  # The topic that tells and changes the seats in a world code.
  CODE_TOPIC = "world.code"

  # The names of a squad rule in the DLL's answers, by the rule's key in the scripts.
  SQUAD_NAMES = { :luka => "luka", :formation => "formation", :front => "front", :raid_front => "raid_front" }

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
  # @return [Boolean] Whether the mod's DLL is installed and no newer release is out.
  def self.available?
    MGQ_Multiplayer.available? && !MGQ_Multiplayer.outdated?
  end

  extend MGQ_MpLog

  # What starts this script's lines in the log.
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
  # @return [Integer, nil] One of difficulties; nil outside Raid Worlds and for a Raid World that
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
    return false unless raid? && difficulties.include?(value)

    @world.change("difficulty" => value)
    true
  end

  # Names a difficulty as the game's own difficulty choice does.
  #
  # @param value [Integer, nil] The difficulty.
  # @return [String, nil] The name, nil for no difficulty.
  def self.difficulty_name(value)
    index = difficulties.index(value)
    index ? difficulty_names[index] : nil
  end

  # Reads a difficulty as world.ini or the list writes it.
  #
  # @param text [String, nil] The text.
  # @return [Integer, nil] One of difficulties, nil for none or another text.
  def self.difficulty_of(text)
    value = text.to_s =~ /\A-?\d\z/ ? text.to_i : nil
    difficulties.include?(value) ? value : nil
  end

  # Reads one of the rules a world's settings follow, as the DLL owns them (WorldTopics in the
  # DLL), asked once.
  #
  # @param name [String] The rule: "seats", "difficulties", "difficulty", "formations", "fronts" or
  #   "squad".
  # @return [Object, nil] The rule as the DLL tells it; nil while the DLL did not answer.
  def self.rule(name)
    @rules ||= MGQ_Multiplayer::Bridge.call(RULES_TOPIC)
    @rules ? @rules[name] : nil
  end

  # Fewest players a world seats.
  #
  # @return [Integer] The seats.
  def self.min_seats
    (rule("seats") || {})["min"].to_i
  end

  # Most players a world seats.
  #
  # @return [Integer] The seats.
  def self.max_seats
    (rule("seats") || {})["max"].to_i
  end

  # Players a new world seats unless the player chooses otherwise.
  #
  # @return [Integer] The seats.
  def self.default_seats
    (rule("seats") || {})["default"].to_i
  end

  # Lists the difficulties a Raid World may set for every player, the game's own values of its
  # difficulty variable, in the order the forms offer them.
  #
  # @return [Array<Integer>] The values.
  def self.difficulties
    Array(rule("difficulties")).map { |value, _| value }
  end

  # Lists the names of the difficulties, as the game's own difficulty choice shows them.
  #
  # @return [Array<String>] The names, in the order of difficulties.
  def self.difficulty_names
    Array(rule("difficulties")).map { |_, name| name }
  end

  # Tells the difficulty the forms offer first.
  #
  # @return [Integer, nil] The value.
  def self.default_difficulty
    rule("difficulty")
  end

  # Lists the Formation sizes a Raid World may set, the team every player keeps, in the order the
  # forms offer them; 0 keeps the game's own team size.
  #
  # @return [Array<Integer>] The sizes.
  def self.formations
    Array(rule("formations")).map { |size, _| size }
  end

  # Lists the Frontline's places a Raid World may give each player's team, in regular fights and in
  # raids, in the order the forms offer them.
  #
  # @return [Array<Integer>] The places.
  def self.fronts
    Array(rule("fronts"))
  end

  # Tells the squad rules of a Raid World that names none.
  #
  # @return [Hash, nil] The rules, see squad; nil while the DLL did not answer.
  def self.default_squad
    squad_from(rule("squad"))
  end

  # Tells the squad rules the open Raid World sets for every player's team.
  #
  # @return [Hash, nil] :luka (whether Luka may leave the team), :formation (one of formations),
  #   :front and :raid_front (the Frontline's places in regular fights and in raids, each one of
  #   fronts); default_squad for a Raid World that names none; nil outside Raid Worlds.
  def self.squad
    raid? ? (@world.squad || default_squad).dup : nil
  end

  # Takes the squad rules the open Raid World's creator or an admin changed, as the relay tells
  # every game in it, and keeps them in world.ini.
  #
  # @param squad [Hash] The rules, as squad tells them.
  # @return [Boolean] Whether the open world is a Raid World that took them.
  def self.take_squad(squad)
    valid = squad.is_a?(Hash) ? squad_of(squad_text(squad)) : nil
    return false unless raid? && valid

    @world.change("squad" => squad_plain(valid))
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
    squad_from(MGQ_Multiplayer::Bridge.call(SQUAD_READ_TOPIC, text.to_s))
  end

  # Writes squad rules the way squad_of reads them.
  #
  # @param squad [Hash] The rules, as squad tells them.
  # @return [String] The text, such as "0 4 1 1"; empty for rules out of range.
  def self.squad_text(squad)
    MGQ_Multiplayer::Bridge.call(SQUAD_WRITE_TOPIC, squad_plain(squad)) || ""
  end

  # Turns squad rules the scripts keep into those the DLL takes.
  #
  # @param squad [Hash, nil] The rules, as squad tells them.
  # @return [Hash, nil] The rules by their names in SQUAD_NAMES; nil for none.
  def self.squad_plain(squad)
    return nil unless squad

    plain = { "luka" => squad[:luka] ? true : false }
    [:formation, :front, :raid_front].each { |key| plain[SQUAD_NAMES[key]] = squad[key].to_i }
    plain
  end

  # Turns squad rules as the DLL tells them into those the scripts keep.
  #
  # @param rules [Hash, nil] The rules by their names in SQUAD_NAMES.
  # @return [Hash, nil] The rules, as squad tells them; nil for none.
  def self.squad_from(rules)
    return nil unless rules.is_a?(Hash)

    squad = {}
    SQUAD_NAMES.each { |key, name| squad[key] = rules[name] }
    squad
  end

  # Names a Formation size for texts, as the DLL names it.
  #
  # @param value [Integer] One of formations.
  # @return [String] "Original" for the game's own team size, else the size as text.
  def self.formation_name(value)
    found = Array(rule("formations")).find { |size, _| size == value.to_i }
    found ? found[1] : value.to_i.to_s
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

    @world.change("raid_bosses" => on ? true : false)
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
  # which the title screen starts once the world screen closed. The Mod Framework enters the game
  # with the world's mods right before the save loads, or at the title right before New Game, since
  # under it the way back to the title would start the game again once entered.
  #
  # @param world [World] The world.
  # @param scene [Scene_MpWorlds] The world screen.
  # @return [String, nil] Why the world could not be entered, nil when it was.
  def self.start(world, scene)
    unless available?
      log("not entering world #{world.id}: worlds are off, the DLL is missing or the mod is outdated")
      return MGQ_Multiplayer.update_message
    end

    enter(world)
    index = world.latest_save

    unless index
      log("world #{world.id} has no save here: starting a new game in it")
      @pending = :new_game
      scene.return_scene
      return nil
    end

    MGQ_MpWorldMods.enter_game if defined?(MGQ_MpWorldMods)
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
    log("entered world #{world.id} (#{world.name}, directory #{short(world.directory_id)}, #{world.seats} seats)")
  end

  # Closes the open world, leaving its room and putting the player's own system save back. The
  # story closes first, so its last writes reach the room before it closes.
  #
  # @param reason [String] Why, for the log.
  def self.leave(reason = "closed")
    return unless @world

    MGQ_MpWorldStory.close if defined?(MGQ_MpWorldStory)
    Link.close
    System.leave
    log("left world #{@world.id} (#{@world.name}): #{reason}")
    @world = nil
  rescue => e
    @world = nil
    log("could not leave the world cleanly: #{e.class}: #{e.message}")
  end

  # Closes the open world once the game went back to the title screen, unless the world screen
  # sent it there to start a new game in the world. Called as the title screen starts.
  def self.on_title_start
    if @pending
      log("kept world #{@world.id} open on the title screen: its new game starts there") if @world
    else
      leave("the game went back to the title screen")
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
    return if Update.asking?
    return Invite.on_title_update(scene) unless @pending == :new_game

    @pending = nil
    log("new game in world #{@world.id}") if @world
    MGQ_MpWorldMods.enter_game if defined?(MGQ_MpWorldMods)
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
    restart_after_backing_out
  end

  # Starts the game again into the world screen once the player backed out of a world's New Game
  # the Mod Framework entered the game for: the title counts as entered with the world's mods until
  # the game starts again, so Continue or another world would run with them.
  def self.restart_after_backing_out
    return unless defined?(MGQ_Multiplayer::Stages) && MGQ_Multiplayer::Stages.staged? && MGQ_Multiplayer::Stages.entered?

    log("the title counts as entered with the world's mods: starting the game again into the world screen")
    Mod_Framework::Mods.restart("the player backed out of a world's New Game", MGQ_Multiplayer::Stages::OPEN_ACTION)
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
    # Under the Mod Framework the command is the framework's, see MGQ_Multiplayer::Stages.
    return if defined?(MGQ_Multiplayer::Stages) && MGQ_Multiplayer::Stages.staged?

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
    return Update.ask(scene) if MGQ_Multiplayer.outdated?

    MGQ_MpGame.call(scene, :close_command_window)
    SceneManager.call(Scene_MpWorlds)
  end

  # Offers the update on the title screen once a newer release is out, as picking Multiplayer
  # does, for what would otherwise open the world screen on its own: a Discord invite, or the
  # entry again after a restart for a world's mods.
  #
  # @param scene [Scene_Title] The title screen.
  def self.offer_update(scene)
    Update.ask(scene) unless Update.asking?
  end

  # What changed in the worlds' models, as the DLL tells it once a frame (WorldChanges in C#): one
  # Integer of bits, so a script asks for rows, details or steps only after a change.
  module Changes
    # The event the bits come with.
    TOPIC = "worlds.changed"

    # The worlds on this PC or in the directory's list changed.
    LIST = 1

    # What a world's details show changed.
    DETAILS = 2

    # The mod catalog or the scripts in Patch changed.
    MODS = 4

    # The shared mod settings have something to apply, lock or tell.
    SETTINGS = 8

    # Turning other mods off has something to show or do.
    PARKING = 16

    # The world screen has a step to play.
    SCREEN = 32

    # The World overview's model changed.
    OVERVIEW = 64

    # Takes whether any of some bits changed since they were last taken; the first look at any bit
    # answers true, since nothing was known before it.
    #
    # @param bits [Integer] The bits, such as LIST | DETAILS.
    # @return [Boolean] Whether any of them changed.
    def self.take?(bits)
      listen
      @seen ||= 0
      changed = (@bits & bits) != 0 || (@seen & bits) != bits
      @seen |= bits
      @bits &= ~bits
      changed
    end

    # Takes the bits of a drain.
    #
    # @param bits [Integer] The bits that changed.
    def self.note(bits)
      @bits = (@bits || 0) | bits.to_i
    end

    # Takes the DLL's events from the first look on.
    def self.listen
      return if @listening

      @listening = true
      @bits ||= 0
      MGQ_Multiplayer::Bridge.on(TOPIC) { |bits| note(bits) }
    end
  end

  # Has the Mod Framework offer the release to play once the player picks Multiplayer while another
  # release is the one, a newer one or a step back the relay asks for: the framework asks, installs
  # it once the game closed and starts the game again into the world screen
  # (MGQ_Multiplayer::Stages::OPEN_ACTION). The title's commands wait meanwhile.
  module Update
    # The mod's slug on the website, by which the Mod Framework finds it.
    SLUG = "mgq-online"

    # Why the player is asked to update.
    REASON = "This version cannot play online."

    # Why the player is asked to install a step back.
    ROLLBACK_REASON = "This version cannot play online right now."

    # Asks the Mod Framework for the release to play; without it, tells the player how to update.
    #
    # @param scene [Scene_Title] The title screen.
    # @return [Boolean] Whether the framework asks.
    def self.ask(scene)
      commands = MGQ_MpGame.get(scene, :command_window)
      commands.deactivate if commands && !commands.disposed?
      version = MGQ_Multiplayer.newer_version
      unless defined?(Mod_Framework::Mods) && Mod_Framework::Mods.respond_to?(:require)
        MGQ_MpWorld.log("release #{version} is the one to play, and no Mod Framework installs it")
        msgbox(MGQ_Multiplayer.update_message) if respond_to?(:msgbox, true)
        give_back(commands)
        return false
      end

      @asking = true
      MGQ_MpWorld.log("asking the Mod Framework for release #{version}#{MGQ_Multiplayer.rollback? ? ', a step back' : ''}")
      Mod_Framework::Mods.require(SLUG, version, :exact => MGQ_Multiplayer.rollback?, :reason => MGQ_Multiplayer.rollback? ? ROLLBACK_REASON : REASON,
                                                 :action => MGQ_Multiplayer::Stages::OPEN_ACTION) do |result|
        @asking = false
        MGQ_MpWorld.log("the Mod Framework's update to #{version}: #{result}")
        give_back(commands) unless result == :restarting
      end
      true
    end

    # Tells whether the Mod Framework asks for the update now.
    #
    # @return [Boolean] Whether it does.
    def self.asking?
      @asking == true
    end

    # Gives the input back to the title's commands.
    #
    # @param commands [Window_TitleCommand, nil] The title's commands.
    def self.give_back(commands)
      commands.activate if commands && !commands.disposed?
    end
  end

  # A world as the world screen lists it: the directory's, this PC's folder of it, or both.
  #
  # @!attribute id [String, nil] The directory's id of the world, nil for a world on this PC whose world.ini names none.
  # @!attribute name [String] The world's name.
  # @!attribute listed [Directory::ListedWorld, nil] The world in the directory, nil once its creator deleted it.
  # @!attribute local [World, nil] The world's folder on this PC, nil before the player entered it.
  # @!attribute favourite [Boolean] Whether the player marked it as a favourite.
  # @!attribute gone [Boolean] Whether the directory no longer has it, as opposed to its list not having arrived.
  # @!attribute key [String, nil] Its row's key in the DLL's model of the world screen (WorldScreen), which names its details.
  # @!attribute row [Hash, nil] Its row as that model draws it: "text", "count", "color" and "dim".
  Entry = Struct.new(:id, :name, :listed, :local, :favourite, :gone, :key, :row) do
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

    # Lists what of the player's game data differs from that of the world's creator.
    #
    # @return [Array<String>, nil] The parts that differ, none when the games match, nil when the directory does not tell.
    def differing
      listed.nil? ? nil : GameData.differing(listed.data)
    end
  end

  # Patch/Multiplayer/Multiplayer.dll's world functions: the connection to the open world's room.
  module Link
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

  end

  # Discord invites into a world: the Discord mod hands over the world code an invite carries, and
  # the world screen enters that world with it instead of asking for its password.
  module Invite
    # What the notification box says when an invite comes in during a game.
    LATER_TEXT = "Discord invite taken: the title screen opens the world."

    # What it says there once the way back to the title starts the game again, which carries the
    # invite.
    RESTART_TEXT = "Discord invite taken: go back to the title screen to open the world."

    # The topic that takes an invite, which the DLL keeps.
    RECEIVE_TOPIC = "worlds.invite"

    # The topic that hands the invite taken last out, once.
    TAKE_TOPIC = "worlds.invite_take"

    # Takes an invite the player accepted in Discord, if it is into a world; one into the world open
    # already is dropped.
    #
    # @param code [String] The invite's join secret.
    # @return [Boolean] Whether it was into a world, which leaves it to the world screen.
    def self.receive(code)
      open = MGQ_MpWorld.open? ? MGQ_MpWorld.world.directory_id : nil
      taken = MGQ_Multiplayer::Bridge.call(RECEIVE_TOPIC, "code" => code.to_s, "open" => open)
      return false unless taken.is_a?(Hash)
      return true unless taken["taken"]

      @waiting = taken["world"]
      carried = carry_through_restart(code)
      MGQ_MpNotices.message(:world_invite, carried ? RESTART_TEXT : LATER_TEXT) if defined?(MGQ_MpNotices) && !SceneManager.scene.is_a?(Scene_Title)
      true
    end

    # Has the restart that the way back to the title makes under the Mod Framework once the player
    # entered the game carry an invite, which the title of the game that starts again takes anew,
    # since the restart drops the invite this game and its DLL keep.
    #
    # @param code [String] The invite's join secret.
    # @return [Boolean] Whether the restart carries it.
    def self.carry_through_restart(code)
      return false unless defined?(MGQ_Multiplayer::Stages) && MGQ_Multiplayer::Stages.restart_needed?
      return false unless Mod_Framework::Mods.respond_to?(:carry_after_restart)

      Mod_Framework::Mods.carry_after_restart(MGQ_Multiplayer::Stages::INVITE_ACTION, code.to_s)
      MGQ_MpWorld.log("the restart on the way back to the title carries the invite into world #{MGQ_MpWorld.short(@waiting)}")
      true
    end

    # Opens the world screen for the invite taken last, which the DLL hands over as the screen
    # opens, or offers the update in its place once a newer release is out. Called by the title
    # screen every frame while nothing else runs.
    #
    # @param scene [Scene_Title] The title screen.
    def self.on_title_update(scene)
      return unless @waiting

      if MGQ_Multiplayer.available? && MGQ_Multiplayer.outdated?
        MGQ_MpWorld.log("not opening the world screen for the invite into world #{MGQ_MpWorld.short(@waiting)}: the mod is outdated")
        drop
        return MGQ_MpWorld.offer_update(scene)
      end
      return unless MGQ_MpWorld.available?

      MGQ_MpWorld.log("opening the world screen for the invite into world #{MGQ_MpWorld.short(@waiting)}")
      @waiting = nil
      SceneManager.call(Scene_MpWorlds)
    end

    # Drops the invite once the world screen will not open for it, which the DLL then forgets too.
    def self.drop
      @waiting = nil
      MGQ_Multiplayer::Bridge.call(TAKE_TOPIC)
    end
  end

  # What tells one game's data from another's: which entries of the database and which maps exist,
  # so a mod that adds or removes any is noticed.
  module GameData
    # The fingerprint's format, which both games must share to be compared.
    FORMAT = 2

    # Most parts a text names before it counts the rest.
    NAMED_PARTS = 4

    # The file in the mod folder the fingerprint is written to at each start, from which the World
    # Admin tool reads an installation's game data: its "fingerprint" and when it was "written", in
    # seconds since 1970.
    FILE = "#{MGQ_Multiplayer::MOD_DIR}\\GameData.ini"

    # The topic that keeps this game's fingerprint in the DLL.
    FINGERPRINT_TOPIC = "worlds.game_data"

    # The topic that compares it with another game's.
    DIFFERING_TOPIC = "worlds.data_differing"

    # The topic that names parts in a sentence.
    TEXT_TOPIC = "worlds.data_text"

    # Finds the fingerprint of this game's data, once per session.
    #
    # It reads no name, since translations name entries the untranslated game leaves unnamed.
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
      used = [$data_actors, $data_classes, $data_skills, $data_items, $data_weapons, $data_armors, $data_enemies, $data_states].map do |entries|
        existing(entries) { |entry| used?(entry) }
      end
      used + [existing($data_troops) { |troop| !troop.members.empty? }, existing($data_common_events) { |event| event.list.size > 1 }, map_ids]
    end

    # Tells whether an entry of the database holds anything: a note, features or effects.
    #
    # It reads the features and effects as the data file holds them, since the game's readers add
    # what the note gives and need the game's analysis, which an entry a mod adds may lack.
    #
    # @param entry [RPG::BaseItem] The entry.
    # @return [Boolean] Whether it does.
    def self.used?(entry)
      !entry.note.to_s.strip.empty? || !MGQ_MpGame.get(entry, :features).to_a.empty? ||
        (entry.respond_to?(:effects) && !MGQ_MpGame.get(entry, :effects).to_a.empty?)
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

    # Lists what of this game's data differs from another game's, through the DLL (GameDataCompare
    # in MGQOnline.Game), each fingerprint asked once.
    #
    # @param other [String, nil] The other game's fingerprint.
    # @return [Array<String>, nil] The parts that differ, none when the games match, nil when they cannot be compared.
    def self.differing(other)
      return nil if other.to_s.empty?

      hand_fingerprint
      key = other.to_s
      return @differing[key] if @differing.key?(key)

      @differing[key] = MGQ_Multiplayer::Bridge.call(DIFFERING_TOPIC, key)
    end

    # Hands this game's fingerprint to the DLL, once per session, and forgets the comparisons made
    # with another.
    def self.hand_fingerprint
      mine = fingerprint
      return if @handed == mine

      @handed = mine
      @differing = {}
      MGQ_Multiplayer::Bridge.call(FINGERPRINT_TOPIC, mine)
    end

    # Names parts in a sentence, the first few by name, as the DLL writes it.
    #
    # @param parts [Array<String>] The parts.
    # @param named [Integer] Most parts named before the rest is counted.
    # @return [String] The text, such as "skills, items and 3 more"; empty when the DLL did not answer.
    def self.text(parts, named = NAMED_PARTS)
      MGQ_Multiplayer::Bridge.call(TEXT_TOPIC, "parts" => parts, "named" => named) || ""
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
    # @!attribute difficulty [Integer, nil] The difficulty a Raid World sets for every player, one of MGQ_MpWorld.difficulties; nil when it sets none.
    # @!attribute other_mods_off [Boolean] Whether it turns off every mod it does not name, see MGQ_MpWorldMods.enter_game.
    # @!attribute squad [Hash, nil] The squad rules a Raid World sets for every player's team, see MGQ_MpWorld.squad; nil when it names none.
    # @!attribute raid_bosses [Boolean] Whether a Classic world's story bosses fight as raid bosses, see MGQ_MpWorld.raid_bosses?.
    # @!attribute mods_unread [Boolean, nil] Whether its mods, mod hashes and settings are not read yet, which the list leaves out
    #   for every world but the one opened, see open; they are empty meanwhile.
    ListedWorld = Struct.new(:id, :seats, :online, :creator_id, :active, :creator_name, :name, :start, :members, :hidden, :choose, :open, :featured, :strict, :data, :mods, :description, :mod_hashes, :settings,
                             :type, :share, :difficulty, :other_mods_off, :squad, :raid_bosses, :mods_unread) do
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

    # Opens a world, whose mods, mod hashes and settings the list then carries: the DLL reads them on
    # a thread of its own whenever the list leaves them out, as the relay does for this version.
    #
    # @param id [String, nil] The world's id, nil for none.
    def self.open(id)
      return if id == @opened

      @opened = id
      MGQ_Multiplayer::Link.function('mp_dir_open').call(id.to_s + "\0")
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
          worlds.push(ListedWorld.new(fields[1], fields[2].to_i, fields[3].to_i, fields[4], fields[5].to_i, fields[6], fields[7], fields[8], [], fields[9] == "1", fields[10] == "1", fields[11] == "1", fields[12] == "1", fields[13] == "1", fields[14], fields[15], fields[16], fields[17], fields[18],
                                     fields[19], fields[20], fields[19] == RAID ? MGQ_MpWorld.difficulty_of(fields[21]) : nil,
                                     fields[22] == "1", fields[19] == RAID ? MGQ_MpWorld.squad_of(fields[23]) : nil,
                                     fields[19] != RAID && fields[24] == "1"))
        when "member"
          worlds.last.members.push(Member.new(fields[1], fields[2] == "1", fields[3].to_s)) if worlds.last
        when "unread"
          worlds.last.mods_unread = true if worlds.last
        end
      end

      [state["state"] || "idle", state["error"], worlds, state["admin"] == "1"]
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
    mods_text(text)["names"]
  end

  # Lists the mods a world's creator marked as required, with an exclamation mark in front: a
  # game needs their script to enter, see installed_mod?.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Their names.
  def self.required_mods(text)
    mods_text(text)["required"]
  end

  # Lists the mods a world's creator marked as essential, with a question mark in front: they
  # stand out, but nothing is looked for, since a mod of data files has no script.
  #
  # @param text [String, nil] The mods as written.
  # @return [Array<String>] Their names.
  def self.essential_mods(text)
    mods_text(text)["essential"]
  end

  # Reads a world's mods as written through the DLL (ModsText in MGQOnline.Game), each text asked
  # once.
  #
  # @param text [String, nil] The mods as written.
  # @return [Hash] "names", "required" and "essential", each an Array of names; none of either
  #   when the DLL did not answer.
  def self.mods_text(text)
    key = text.to_s
    @mods_texts ||= {}
    return @mods_texts[key] if @mods_texts.key?(key)

    read = MGQ_Multiplayer::Bridge.call(TEXT_TOPIC, key)
    return { "names" => [], "required" => [], "essential" => [] } unless read.is_a?(Hash)

    @mods_texts.clear if @mods_texts.size >= MODS_TEXTS_KEPT
    @mods_texts[key] = read
  end

  # Tells whether a mod's script is installed: a .rb file of the mod's name anywhere in the Patch
  # folder, whatever its case and whether it writes spaces, underscores or hyphens.
  #
  # @param name [String] The mod's name, with or without ".rb".
  # @return [Boolean] Whether it is; also when the folder cannot be read, so nobody is kept out by mistake.
  def self.installed_mod?(name)
    scripts = installed_scripts
    return true unless scripts

    key = mod_key(name)
    scripts.any? { |script| script[0] == key }
  end

  # Finds a mod's script in the Patch folder, as installed_mod? does.
  #
  # @param name [String] The mod's name, with or without ".rb".
  # @return [String, nil] Its path relative to the game's folder, nil when it is not installed or the folder cannot be read.
  def self.installed_path(name)
    key = mod_key(name)
    found = (installed_scripts || []).find { |script| script[0] == key }
    found && found[1]
  end

  # Lists the scripts the Patch folder holds, as the DLL reads them, since the game's Ruby reads file
  # names in the system's code page.
  #
  # @return [Array<Array>, nil] Each script's key (see mod_key), path relative to the game's folder
  #   and name without ".rb"; nil when the folder cannot be read.
  def self.installed_scripts
    return @installed if @installed

    @installed = MGQ_Multiplayer::Bridge.call(INSTALLED_TOPIC)
    return log_once(:installed, "reading the Patch folder failed, so every required mod counts as installed") unless @installed

    log("the Patch folder holds #{@installed.size} script(s): #{@installed.map { |script| script[0] }.join(', ')}")
    @installed
  end

  # Forgets which scripts the Patch folder holds, so the next look reads it anew.
  def self.forget_installed
    @installed = nil
  end

  # Turns a mod's name or its script's file name into what the two are compared by, as the DLL and
  # the relay make it (ModKey in MGQOnline.Game), each name asked once.
  #
  # @param name [String] The name.
  # @return [String] The key: the name in lower case, without ".rb", white space, underscores and
  #   hyphens; the name itself when the DLL did not answer.
  def self.mod_key(name)
    text = name.to_s
    @mod_keys ||= {}
    return @mod_keys[text] if @mod_keys.key?(text)

    keys = MGQ_Multiplayer::Bridge.call(KEYS_TOPIC, [text])
    return text unless keys.is_a?(Array) && keys[0].is_a?(String)

    @mod_keys[text] = keys[0]
  end

  # The hidden worlds the player added to their list by their ids, which the relay lists for
  # whoever names them, kept in Player.ini by the DLL (WorldLists).
  module Added
    # The topic that lists them.
    ALL_TOPIC = "worlds.added"

    # Lists the worlds added.
    #
    # @return [Array<String>] Their directory ids, the one added last at the end.
    def self.all
      ids = MGQ_Multiplayer::Bridge.call(ALL_TOPIC)
      ids.is_a?(Array) ? ids : []
    end
  end

  # A world on this PC as the DLL keeps it (LocalWorlds): its folder in Patch/Multiplayer/Worlds,
  # named by a hash of its code, with world.ini (name, world code, directory id, type, how a Raid
  # World shares companions, its difficulty and squad rules, whether a Classic world fights raid
  # bosses, when it was made and last played) and the world's Save folder. The script keeps a copy
  # of its fields, since the open world's are read every frame.
  class World
    # The topic that lists the worlds on this PC.
    LOCAL_TOPIC = "worlds.local"

    # The topic that makes a world's folder or finds the one there is.
    FOUND_TOPIC = "worlds.found"

    # The topic that describes a world anew as the directory says it.
    DESCRIBE_TOPIC = "worlds.describe"

    # The topic that changes a world and writes its world.ini.
    UPDATE_TOPIC = "worlds.update"

    # The topic that finds a world's latest save.
    LATEST_SAVE_TOPIC = "worlds.latest_save"

    # Lists the worlds on this PC.
    #
    # @return [Array<World>] The worlds; none when the DLL did not answer.
    def self.all
      worlds = MGQ_Multiplayer::Bridge.call(LOCAL_TOPIC)
      worlds.is_a?(Array) ? worlds.map { |values| new(values) } : []
    end

    # Makes a world's folder, or finds the one there is, and describes the world in it.
    #
    # @param code [String] The world code.
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @param type [String, nil] Its type, one of TYPES; nil to keep what world.ini says.
    # @param share [String, nil] How a Raid World shares companions, one of SHARING; nil to keep what world.ini says.
    # @param difficulty [Integer, nil] A Raid World's difficulty, one of MGQ_MpWorld.difficulties; nil to keep what world.ini says.
    # @param squad [Hash, nil] A Raid World's squad rules, see MGQ_MpWorld.squad; nil to keep what world.ini says.
    # @param raid_bosses [Boolean, nil] Whether a Classic world fights raid bosses; nil to keep what world.ini says.
    # @return [World, nil] The world, nil when the text is no world code, the folder could not be
    #   made or its world.ini exists but could not be read, which is then left as it is.
    def self.found(code, name, directory_id, type = nil, share = nil, difficulty = nil, squad = nil, raid_bosses = nil)
      values = MGQ_Multiplayer::Bridge.call(FOUND_TOPIC, about(name, directory_id, type, share, difficulty, squad, raid_bosses).merge("code" => code.to_s))
      values.is_a?(Hash) ? new(values) : nil
    end

    # Writes what the directory says of a world as the DLL takes it.
    #
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @param type [String, nil] Its type, nil to keep what world.ini says.
    # @param share [String, nil] How a Raid World shares companions, nil to keep it.
    # @param difficulty [Integer, nil] A Raid World's difficulty, nil to keep it.
    # @param squad [Hash, nil] A Raid World's squad rules, nil to keep them.
    # @param raid_bosses [Boolean, nil] Whether a Classic world fights raid bosses, nil to keep it.
    # @return [Hash] The request's fields, see found.
    def self.about(name, directory_id, type, share, difficulty, squad, raid_bosses)
      { "name" => name.to_s, "world" => directory_id, "type" => type, "share" => share, "difficulty" => difficulty,
        "squad" => MGQ_MpWorld.squad_plain(squad), "raid_bosses" => raid_bosses.nil? ? nil : (raid_bosses ? true : false) }
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

    # When the world was played last, nil before.
    attr_reader :played_at

    # The world's type, one of TYPES, nil when world.ini names none, which counts as Classic.
    attr_reader :type

    # How a Raid World shares companions, one of SHARING, nil when world.ini names none.
    attr_reader :share

    # The difficulty a Raid World sets for every player, one of MGQ_MpWorld.difficulties, nil when world.ini names none.
    attr_reader :difficulty

    # The squad rules a Raid World sets for every player's team, see MGQ_MpWorld.squad, nil when
    # world.ini names none.
    attr_reader :squad

    # Whether a Classic world's story bosses fight as raid bosses, see MGQ_MpWorld.raid_bosses?.
    attr_reader :raid_bosses

    # How many players the world seats at once, which its code tells, 0 for a code that tells none.
    attr_reader :seats

    # Creates a world from what the DLL tells of it.
    #
    # @param values [Hash] The world, as worlds.local tells each.
    def initialize(values)
      take(values)
    end

    # Takes what the DLL tells of the world.
    #
    # @param values [Hash] The world, as worlds.local tells each.
    # @return [World] self.
    def take(values)
      @id = values["id"]
      @name = values["name"]
      @code = values["code"]
      @directory_id = values["world"]
      @played_at = values["played"] ? Time.at(values["played"]) : nil
      @type = values["type"]
      @share = values["share"]
      @difficulty = values["difficulty"]
      @squad = MGQ_MpWorld.squad_from(values["squad"])
      @raid_bosses = values["raid_bosses"] == true
      @seats = values["seats"].to_i
      self
    end

    # Takes the world's name, directory id, seats, type, companion sharing, difficulty, squad rules
    # and raid bosses, as the directory says them, which the DLL writes into world.ini at once.
    #
    # @param name [String] The world's name.
    # @param directory_id [String] The world's id in the directory.
    # @param seats [Integer, nil] How many players it seats now, which its creator may change; nil to keep what the code tells.
    # @param type [String, nil] Its type, one of TYPES; nil to keep what world.ini says.
    # @param share [String, nil] How a Raid World shares companions, one of SHARING; nil to keep what world.ini says.
    # @param difficulty [Integer, nil] A Raid World's difficulty, one of MGQ_MpWorld.difficulties; nil to keep what world.ini says.
    # @param squad [Hash, nil] A Raid World's squad rules, see MGQ_MpWorld.squad; nil to keep what world.ini says.
    # @param raid_bosses [Boolean, nil] Whether a Classic world fights raid bosses; nil to keep what world.ini says.
    def describe(name, directory_id, seats = nil, type = nil, share = nil, difficulty = nil, squad = nil, raid_bosses = nil)
      request = World.about(name, directory_id, type, share, difficulty, squad, raid_bosses).merge("id" => @id, "seats" => seats && seats.to_i)
      values = MGQ_Multiplayer::Bridge.call(DESCRIBE_TOPIC, request)
      take(values) if values.is_a?(Hash)
    end

    # Changes the world and writes its world.ini.
    #
    # @param changes [Hash] Any of "difficulty", "squad" (as squad_plain writes it), "raid_bosses" and "played" (true: played now).
    # @return [Boolean] Whether it was written.
    def change(changes)
      answer = MGQ_Multiplayer::Bridge.call(UPDATE_TOPIC, { "id" => @id }.merge(changes))
      return false unless answer.is_a?(Hash)

      take(answer["world"])
      answer["written"] == true
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

    # The folder of the world's saves, which the game's Save folder stands for while it is open.
    #
    # @return [String] The folder, relative to the game's folder.
    def save_folder
      "#{folder}/Save"
    end

    # Notes that the world is played now.
    #
    # @return [Boolean] Whether world.ini was written.
    def played!
      change("played" => true)
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
      latest && latest[1]
    end

    # Finds the world's latest save and its file, from the files themselves, since the game only
    # finds a world's saves while the world is open.
    #
    # @return [Array, nil] The save's index as DataManager takes it and its file's path relative to
    #   the game's folder, nil without any save.
    def latest_save_entry
      latest = MGQ_Multiplayer::Bridge.call(LATEST_SAVE_TOPIC, @id)
      latest.is_a?(Array) ? latest : nil
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
        # Ruby 1.9 has no keywords; from 2.7 on, a call such as File.read(path, encoding: ...)
        # would hand its keywords on as a hash in place of a length without this.
        owner.singleton_class.send(:ruby2_keywords, name) if owner.singleton_class.respond_to?(:ruby2_keywords, true)
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

  # A form filled in on this game alone: its fields, laid out in rows, and what is filled in, which
  # the story's choices and the bug report keep themselves. The world screen's forms are WorldForms,
  # which the DLL holds.
  class Form
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

      # What the lines at the top of the screen say while the cursor is on the field.
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

      # Tells whether another field is the same one, as a form the DLL holds hands out each field
      # anew with every view.
      #
      # @param other [Object] The other field.
      # @return [Boolean] Whether it has the same key, kind and place.
      def ==(other)
        other.is_a?(Field) && [other.key, other.kind, other.row, other.side] == [@key, @kind, @row, @side]
      end
      alias eql? ==

      # Makes the field's hash, which a field equal to it shares.
      #
      # @return [Integer] The hash.
      def hash
        [@key, @kind, @row, @side].hash
      end
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

    # Moves a switch to its next or its previous outcome, round.
    #
    # @param field [Field] The switch.
    # @param step [Integer] 1 for the next outcome, -1 for the previous.
    # @return [Integer] The outcome's index now.
    def turn(field, step)
      count = [field.choices.size, 1].max
      @values[field.key] = (@values[field.key].to_i + step) % count
    end

    # Ticks a checkbox, or unticks it.
    #
    # @param key [Symbol] The checkbox's key.
    # @return [Boolean] Whether it is ticked now.
    def tick(key)
      @values[key] = !@values[key]
    end

    # Checks what a text box holds, and tidies it.
    #
    # @param field [Field] The text box.
    # @param text [String] What it holds.
    # @return [Array] The tidied text, and why it is not accepted, nil when it is.
    def check(field, text)
      # A password keeps its spaces, since the others type it exactly, and may be empty.
      return [text, nil] if field.kind == :password

      tidy = text.strip
      tidy.empty? && !field.may_be_empty? ? [text, field.empty_text] : [tidy, nil]
    end

    # Tells whether Enter in the form's text box sends it, which a form of this game alone leaves to
    # its button.
    #
    # @return [Boolean] false.
    def sends_on_enter?
      false
    end

    # Finds the first field that keeps the form from being sent.
    #
    # @return [Array, nil] The field's index and why, nil when the form can be sent.
    def problem
      fields.each_with_index do |field, index|
        next unless enabled?(field)

        error = field.typed? ? check(field, @values[field.key])[1] : nil
        return [index, error] if error
      end
      nil
    end
  end

  # A form of the world screen whose fields, rules and values the DLL holds (topics form.*,
  # WorldForms in MGQOnline.Game): it draws as a Form does, keeps a copy of what the DLL showed last,
  # and hands over each change the player makes. Its page of the squad rules (limits) shares its
  # values.
  class WorldForm < Form
    # The topic that opens a form in a slot.
    OPEN_TOPIC = "form.open"

    # The topic that hands out a page's view.
    VIEW_TOPIC = "form.view"

    # The topic that sets what a field holds.
    SET_TOPIC = "form.set"

    # The topic that turns a switch.
    TURN_TOPIC = "form.turn"

    # The topic that ticks a checkbox.
    TICK_TOPIC = "form.tick"

    # The topic that checks a text box's text.
    CHECK_TOPIC = "form.check"

    # The topic that sends a page, or names what keeps it from being sent.
    SEND_TOPIC = "form.send"

    # The topic that forgets a slot's form.
    CLOSE_TOPIC = "form.close"

    # The page of a Raid World's squad rules.
    LIMITS_PAGE = "limits"

    # The fact that Discord told the player's name, so the name form may stay empty.
    DISCORD_FACT = "discord"

    # The characters a text box takes, by the name the DLL gives them.
    ALLOWED = { "digits" => /\A\d\z/, "hex" => /\A[0-9a-f]\z/i }

    # What a page says when the DLL did not answer.
    FAILED_TEXT = "Something went wrong. Try again."

    # What a page holds while the DLL did not answer.
    NO_VIEW = { "title" => "", "fields" => [], "values" => {}, "derived" => {} }

    # The form of a new world, empty but for the defaults.
    #
    # @param slot [Symbol] The world screen's name of the form.
    # @return [WorldForm] The form.
    def self.create(slot)
      open(slot, "create")
    end

    # The form that changes a world, for its creator or an admin: what may change after it was made.
    #
    # @param slot [Symbol] The world screen's name of the form.
    # @param listed [Directory::ListedWorld] The world in the directory.
    # @param own [Boolean] Whether the player made the world, and so may replace its game data and
    #   choose whether it shares their mod settings.
    # @return [WorldForm] The form, filled in as the world is.
    def self.edit(slot, listed, own)
      squad = listed.squad && { "luka" => listed.squad[:luka] ? true : false, "formation" => listed.squad[:formation], "front" => listed.squad[:front],
                                "raid_front" => listed.squad[:raid_front] }
      world = { "name" => listed.name.to_s, "seats" => listed.seats.to_i, "mods" => listed.mods.to_s, "description" => listed.description.to_s,
                "shared" => MGQ_MpWorldMods.shared?(listed.settings), "difficulty" => listed.difficulty, "raid" => listed.type == RAID,
                "other_mods_off" => listed.other_mods_off ? true : false, "raid_bosses" => listed.raid_bosses ? true : false, "squad" => squad }
      open(slot, "edit", "world" => world, "own" => own ? true : false)
    end

    # The form of the name the others see, which may stay empty once Discord told the player's name.
    #
    # @param slot [Symbol] The world screen's name of the form.
    # @param name [String] The name as it is, "" for none.
    # @return [WorldForm] The form, filled in with the name.
    def self.rename(slot, name)
      facts = lambda { MGQ_MpWorld.discord_name? ? [DISCORD_FACT] : [] }
      open(slot, "rename", { "name" => name.to_s, "discord" => facts.call.include?(DISCORD_FACT) }, facts)
    end

    # The form of a world's password, which enters it.
    #
    # @param slot [Symbol] The world screen's name of the form.
    # @param name [String] The world's name.
    # @return [WorldForm] The form, empty.
    def self.password(slot, name)
      open(slot, "password", "name" => name.to_s)
    end

    # The form that adds a hidden world to the list by its id.
    #
    # @param slot [Symbol] The world screen's name of the form.
    # @return [WorldForm] The form, empty.
    def self.join(slot)
      open(slot, "join")
    end

    # Opens a form in the DLL.
    #
    # @param slot [Symbol] The world screen's name of the form.
    # @param kind [String] The form, as WorldForms names it.
    # @param seed [Hash] What it opens with.
    # @param facts [Proc, nil] Tells the facts that hold as the player acts, nil for none.
    # @return [WorldForm] The form, empty when the DLL did not answer.
    def self.open(slot, kind, seed = {}, facts = nil)
      view = MGQ_Multiplayer::Bridge.call(OPEN_TOPIC, seed.merge("form" => slot.to_s, "kind" => kind))
      new(slot.to_s, nil, { :serial => 0, :values => {} }, view || NO_VIEW, facts)
    end

    # Creates a page's copy of what the DLL holds.
    #
    # @param slot [String] The form's slot.
    # @param page [String, nil] The page, nil for the main one.
    # @param shared [Hash] What the form's pages share: :values and the :serial of the last view.
    # @param view [Hash] The page's view.
    # @param facts [Proc, nil] Tells the facts that hold as the player acts.
    def initialize(slot, page, shared, view, facts)
      @slot = slot
      @page = page
      @shared = shared
      @facts = facts
      take(view)
    end

    # The page of the squad rules, which holds the same values, so whatever it changes this form keeps.
    #
    # @return [WorldForm] The page, the same one each time.
    def limits
      @limits ||= WorldForm.new(@slot, LIMITS_PAGE, @shared, MGQ_Multiplayer::Bridge.call(VIEW_TOPIC, "form" => @slot, "page" => LIMITS_PAGE) || NO_VIEW, @facts)
    end

    # Forgets the form in the DLL.
    def close
      MGQ_Multiplayer::Bridge.call(CLOSE_TOPIC, "form" => @slot)
    end

    # What the page is called.
    #
    # @return [String] The title.
    def title
      fresh
      @title
    end

    # Lists the fields that are part of the page now, in the order the cursor visits them.
    #
    # @return [Array<Field>] The fields.
    def fields
      fresh
      @fields
    end

    # Reads what a field holds, as the DLL showed it last or the player set it since.
    #
    # @param key [Symbol] The field's key.
    # @return [Object] The value.
    def [](key)
      @shared[:values][key]
    end

    # Sets what a field holds, handing it to the DLL when it changed; the next read of a page then
    # takes its view anew, unless the value is a text.
    #
    # @param key [Symbol] The field's key.
    # @param value [String, Integer, Boolean, nil] The value.
    def []=(key, value)
      values = @shared[:values]
      return if values.key?(key) && values[key] == value

      values[key] = value
      call(SET_TOPIC, "key" => key.to_s, "value" => value)
      # A switch, a checkbox or a save may change what shows, a typed text never does.
      @shared[:serial] += 1 unless value.is_a?(String)
    end

    # Tells whether a field can be used.
    #
    # @param field [Field] The field.
    # @return [Boolean] Whether it can.
    def enabled?(field)
      fresh
      @enabled[field.key] == true
    end

    # Moves a switch to its next or its previous outcome, round, which other fields may follow.
    #
    # @param field [Field] The switch.
    # @param step [Integer] 1 for the next outcome, -1 for the previous.
    # @return [Integer] The outcome's index now.
    def turn(field, step)
      act(TURN_TOPIC, "key" => field.key.to_s, "step" => step)
      self[field.key]
    end

    # Ticks a checkbox, or unticks it, which from then on keeps what the player chose.
    #
    # @param key [Symbol] The checkbox's key.
    # @return [Boolean] Whether it is ticked now.
    def tick(key)
      act(TICK_TOPIC, "key" => key.to_s)
      self[key]
    end

    # Checks what a text box holds, and tidies it.
    #
    # @param field [Field] The text box.
    # @param text [String] What it holds.
    # @return [Array] The tidied text, and why it is not accepted, nil when it is.
    def check(field, text)
      answer = call(CHECK_TOPIC, "key" => field.key.to_s, "text" => text.to_s, "facts" => facts)
      answer.is_a?(Array) ? answer : [text, FAILED_TEXT]
    end

    # Sends the page: finds the first field that keeps it from being sent, or, once none does, takes
    # every text box as the DLL tidied it.
    #
    # @return [Array, nil] The field's index and why, nil when the page can be sent.
    def problem
      answer = call(SEND_TOPIC, "facts" => facts)
      return [0, FAILED_TEXT] unless answer.is_a?(Hash)

      key, reason = answer["problem"]
      return [fields.index { |field| field.key.to_s == key } || 0, reason] if reason

      take(answer)
      nil
    end

    # Tells whether Enter in the page's text box sends it.
    #
    # @return [Boolean] Whether it does.
    def sends_on_enter?
      fresh
      @view["sends_on_enter"] == true
    end

    # Tells the world type the page picks.
    #
    # @return [String] One of TYPES.
    def type
      derived("type") || CLASSIC
    end

    # Tells how the page has a Raid World share companions.
    #
    # @return [String] One of SHARING; "off" for a Classic world.
    def share
      derived("share") || SHARING[0]
    end

    # Tells the difficulty the page picks.
    #
    # @return [Integer, nil] One of MGQ_MpWorld.difficulties; nil for every player's own.
    def difficulty
      derived("difficulty")
    end

    # Tells the squad rules the page picks.
    #
    # @return [Hash] The rules, see MGQ_MpWorld.squad.
    def squad
      MGQ_MpWorld.squad_from(derived("squad")) || MGQ_MpWorld.default_squad
    end

    # Tells whether new players start from one of the creator's saves.
    #
    # @return [Boolean] Whether they do.
    def from_save?
      derived("from_save") == true
    end

    # Tells whether a Classic world's story bosses fight as raid bosses.
    #
    # @return [Boolean] Whether they do.
    def raid_bosses?
      derived("raid_bosses") == true
    end

    # Tells whether each new player of a Classic world chooses where to start.
    #
    # @return [Boolean] Whether they do.
    def choose?
      derived("choose") == true
    end

    # Tells whether the world turns off every mod it does not name.
    #
    # @return [Boolean] Whether it does.
    def other_mods_off?
      derived("other_mods_off") == true
    end

    private

    # Reads what the values add up to, as the DLL tells it.
    #
    # @param name [String] The sum, such as "type".
    # @return [Object, nil] Its value.
    def derived(name)
      fresh
      (@view["derived"] || {})[name]
    end

    # Runs an action on the page and takes the view it answers.
    #
    # @param topic [String] The action's topic.
    # @param request [Hash] What it needs besides the slot and the page.
    def act(topic, request)
      view = call(topic, request)
      take(view) if view.is_a?(Hash)
    end

    # Calls a topic of the form.
    #
    # @param topic [String] The topic.
    # @param request [Hash] What it needs besides the slot and the page.
    # @return [Object, nil] The answer.
    def call(topic, request = {})
      MGQ_Multiplayer::Bridge.call(topic, request.merge("form" => @slot, "page" => @page))
    end

    # Tells the facts that hold now.
    #
    # @return [Array<String>, nil] The facts, nil to keep those the form opened with.
    def facts
      @facts ? @facts.call : nil
    end

    # Reads the page anew when another page of the form acted since it was last read.
    def fresh
      return if @seen == @shared[:serial]

      view = call(VIEW_TOPIC)
      take(view) if view.is_a?(Hash)
      @seen = @shared[:serial]
    end

    # Takes a view as the page's copy, and its values as every page's.
    #
    # @param view [Hash] The view.
    def take(view)
      @title = view["title"].to_s
      @enabled = {}
      @fields = Array(view["fields"]).map do |about|
        field = field_of(about)
        @enabled[field.key] = about["enabled"] == true
        field
      end
      values = {}
      (view["values"] || {}).each { |key, value| values[key.to_sym] = value }
      @shared[:values] = values
      @view = view
      @seen = @shared[:serial] += 1
    end

    # Makes the field a view describes.
    #
    # @param about [Hash] The field, as the view tells it.
    # @return [Field] The field.
    def field_of(about)
      Field.new(about["key"].to_sym, about["kind"].to_sym, about["label"].to_s, about["row"].to_i, about["hint"].to_s,
                :side => about["side"] && about["side"].to_sym, :max_chars => about["max_chars"], :allowed => ALLOWED[about["allowed"]],
                :optional => about["optional"] == true, :group => about["group"], :lines => about["lines"], :choices => Array(about["choices"]),
                :label_width => about["label_width"])
    end
  end

  # The mods of a world as the mod picker shows them, which the DLL keeps (ModPick in
  # MGQOnline.Game): every mod the Patch folder holds, each unlisted, listed, required or
  # essential, then the mods added by name, which this game lacks.
  class ModPick
    # How a mod can be named, in the order the picker offers them.
    STATES = [:unlisted, :listed, :required, :essential]

    # The topic that opens the picker.
    OPEN_TOPIC = "modpick.open"

    # The topic that changes it.
    ACT_TOPIC = "modpick.act"

    # The topic that closes it.
    CLOSE_TOPIC = "modpick.close"

    # A mod of the picker.
    #
    # @!attribute name [String] Its name, the script's file name for an installed one.
    # @!attribute state [Symbol] One of STATES.
    # @!attribute installed [Boolean] Whether the Patch folder holds it.
    # @!attribute label [String] What the right end of its row says.
    # @!attribute color [Symbol] Its row's color: :grey, :plain, :bad or :gold.
    Entry = Struct.new(:name, :state, :installed, :label, :color)

    # The mods, the installed ones first.
    attr_reader :entries

    # The mods named, the way a world keeps them: each with its mark, separated by semicolons.
    attr_reader :text

    # Opens the picker on the mods a world names and the player's installed ones; a named mod the
    # player lacks follows them as added.
    #
    # @param text [String, nil] The mods as written, see MGQ_MpWorld.mods_of.
    def initialize(text)
      @entries = []
      @text = ""
      show(MGQ_Multiplayer::Bridge.call(OPEN_TOPIC, "text" => text.to_s))
    end

    # Tells whether every installed mod is named.
    #
    # @return [Boolean] Whether it is; also when none is installed.
    def all_listed?
      @all_listed == true
    end

    # Names a mod another way. An added mod unlisted stays in the picker, but out of the text.
    #
    # @param index [Integer] The mod's index in entries.
    # @param state [Symbol] One of STATES.
    # @return [String, nil] Why it cannot, nil when it was done.
    def set(index, state)
      act("do" => "set", "index" => index, "state" => state.to_s)
    end

    # Takes a mod added by name out of the picker. An installed mod stays, since the Patch folder
    # holds it.
    #
    # @param index [Integer] The mod's index in entries.
    # @return [Boolean] Whether it was taken out.
    def remove(index)
      act("do" => "remove", "index" => index) == true
    end

    # Lists an unlisted mod, or unlists a named one.
    #
    # @param index [Integer] The mod's index in entries.
    # @return [String, nil] Why it cannot, nil when it was done.
    def toggle(index)
      act("do" => "toggle", "index" => index)
    end

    # Makes a mod required or essential, or only listed again when it is so already.
    #
    # @param index [Integer] The mod's index in entries.
    # @param state [Symbol] :required or :essential.
    # @return [String, nil] Why it cannot, nil when it was done.
    def mark(index, state)
      act("do" => "mark", "index" => index, "state" => state.to_s)
    end

    # Lists every unlisted installed mod, in order, until the text would grow too long.
    #
    # @return [String, nil] Why the rest could not be listed, nil when all were.
    def list_all
      act("do" => "list_all")
    end

    # Unlists every installed mod; the mods added by name stay.
    #
    # @return [nil] Nothing, since unlisting always fits.
    def unlist_all
      act("do" => "unlist_all")
    end

    # Adds a mod the player lacks by its name, listed.
    #
    # @param name [String] The name as typed.
    # @return [String, nil] Why it cannot, nil when it was added.
    def add(name)
      act("do" => "add", "name" => name.to_s)
    end

    # Closes the picker in the DLL.
    def close
      MGQ_Multiplayer::Bridge.call(CLOSE_TOPIC)
    end

    private

    # Changes the picker through the DLL and takes it as it left it.
    #
    # @param request [Hash] The change, see modpick.act.
    # @return [Object] The change's answer, nil when the DLL did not answer.
    def act(request)
      answer = MGQ_Multiplayer::Bridge.call(ACT_TOPIC, request)
      return nil unless answer.is_a?(Hash)

      show(answer["pick"])
      answer["answer"]
    end

    # Takes the picker as the DLL tells it, keeping each entry's object while the mods stay as many,
    # so an entry read before a change tells its new state.
    #
    # @param view [Hash, nil] The picker, as modpick.open tells it.
    def show(view)
      return unless view.is_a?(Hash)

      rows = view["entries"]
      @entries = [] if rows.size != @entries.size
      rows.each_with_index do |(name, state, installed, label, color), index|
        entry = (@entries[index] ||= Entry.new)
        entry.name = name
        entry.state = state.to_sym
        entry.installed = installed
        entry.label = label
        entry.color = color.to_sym
      end
      @text = view["text"]
      @all_listed = view["all_listed"]
    end
  end
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # Before the title screen starts, a world the game came back from closes.
  MGQ_MpHooks.before(Scene_Title, :start, "world") { MGQ_MpWorld.on_title_start }

  # As the title screen first opens, the game data for the World Admin tool.
  MGQ_MpHooks.after(Scene_Title, :start, "world") { MGQ_MpWorld::GameData.write_file }

  # After the title screen's update, a new game starts in a world the world screen opened.
  MGQ_MpHooks.after(Scene_Title, :update, "world") { MGQ_MpWorld.on_title_update(self) unless scene_changing? }

  # A world's new game that asked something first has started once the game sets it up.
  MGQ_MpHooks.before(DataManager.singleton_class, :setup_new_game, "world") { MGQ_MpWorld.new_game_started }

  # The title screen's commands, Multiplayer below Continue, which opens the world screen.
  MGQ_MpHooks.after(Window_TitleCommand, :make_command_list, "world") { MGQ_MpWorld.add_title_command(self) }
  MGQ_MpHooks.after(Scene_Title, :create_command_window, "world") do
    commands = MGQ_MpGame.get(self, :command_window)
    commands.set_handler(:mgq_mp_world, lambda { MGQ_MpWorld.open_world_screen(self) }) if commands
  end
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
