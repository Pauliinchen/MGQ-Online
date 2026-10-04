#----------------------------------------------------------------
#  world_save_distribution.rbx
#
#  Changelog:
#      Paulinchen  2026-10-04: Renamed from mp_save_distribution.rbx
#      Paulinchen  2026-10-03: Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Let a new player of a world whose players choose start from one of their own saves
#      Paulinchen  2026-09-30: Moved into Patch/Multiplayer/Scripts as world_save_distribution.rbx, which Multiplayer.rb loads
#                            - Created
#
#----------------------------------------------------------------

# A world's starting save: one of the creator's own saves, with their system save, which every new
# player of the world starts from instead of the opening. The creator picks it when making the
# world, and it can never be changed. The relay keeps it encrypted with a key from the world's
# token; a new player's game fetches it into the world's folder before entering the world for the
# first time, where it is the world's first save.
#
# A world made with Player's choice instead asks each new player where to start: at the beginning,
# from one of their own saves, copied into the world's folder the same way, or from the starting
# save when it has one.
#
# world.rbx, which loads later, calls it from the world screen. It must never interrupt the game,
# so every entry point rescues.
module MGQ_MpSaveDistribution
  # The starting save's name in a world's folder: the world's first save.
  SAVE_NAME = "Save01.rvdata2"

  # The name of the starting save's thumbnail in a world's folder.
  THUMBNAIL_NAME = "Save01.png"

  # The name of the starting save's system save in a world's folder.
  SYSTEM_NAME = "SystemSave.rvdata2"

  # The system save the game keeps when it cannot say which of its two is newer.
  SYSTEM_FALLBACK = "Save/SystemSave.rvdata2"

  # What Marshal says when a save holds an object of a class the game lacks.
  MISSING_CLASS = /undefined class\/module (\S+)/

  # What the save screen says, by what the save is chosen for: a new world's starting save, or
  # the player's own start in a world whose players choose.
  HELP_TEXTS = {
    :world => "Choose the save every new player of the world starts from.",
    :own => "Choose the save you start from in the world. Your own saves stay as they are.",
  }

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "starting save"

  # Opens the save screen to pick a save.
  #
  # @param purpose [Symbol] What the save is for, a key of HELP_TEXTS.
  def self.choose(purpose)
    @chosen = nil
    @purpose = purpose
    SceneManager.call(Scene_MpStartSave)
  end

  # Tells what the save screen says.
  #
  # @return [String] The text.
  def self.help
    HELP_TEXTS[@purpose]
  end

  # Keeps the save the player picked.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  def self.chosen=(index)
    @chosen = index
  end

  # Hands out what the save screen was opened for and the save the player picked, once.
  #
  # @return [Array] The purpose, nil when the save screen was not opened; and the save's index,
  #   nil when the player left it without one.
  def self.take_chosen
    taken = [@purpose, @chosen]
    @purpose = @chosen = nil
    taken
  end

  # Lists the files a starting save is made of: the save, its thumbnail when it has one, and the
  # player's newest system save, each under the name a new player gets it by.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  # @return [Array<Array<String>>] Each file's name in the world's folder and its path in the game's folder.
  def self.files_of(index)
    DataManager.save_system
    files = [[SAVE_NAME, DataManager.make_filename(index)]]
    thumbnail = DataManager.respond_to?(:make_thumbnailname) ? DataManager.make_thumbnailname(index) : nil
    files.push([THUMBNAIL_NAME, thumbnail]) if thumbnail && File.exist?(thumbnail)
    system = newest_system_save
    files.push([SYSTEM_NAME, system]) if File.exist?(system)
    files
  end

  # Finds the player's newest system save, since the game takes turns writing two.
  #
  # @return [String] Its path in the game's folder.
  def self.newest_system_save
    defined?(SaveSystemData) && SaveSystemData.respond_to?(:load_filename) ? SaveSystemData.load_filename : SYSTEM_FALLBACK
  rescue
    SYSTEM_FALLBACK
  end

  # Writes the files as Patch/Multiplayer/Multiplayer.dll takes them.
  #
  # @param files [Array<Array<String>>] Each file's name in the world's folder and its path in the game's folder.
  # @return [String] One line per file, its name, "=" and its path; empty for none.
  def self.text_of(files)
    files.map { |name, path| "#{name}=#{path}" }.join("\n")
  end

  # Copies the starting save into the creator's own folder of the new world, so the creator
  # starts from it too without fetching it back.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @param files [Array<Array<String>>] Each file's name in the world's folder and its path in the game's folder.
  # @return [Boolean] Whether every file was copied.
  def self.place(world, files)
    Dir.mkdir(world.save_folder) unless File.directory?(world.save_folder)
    files.each do |name, path|
      bytes = File.open(path, "rb") { |file| file.read }
      File.open("#{world.save_folder}/#{name}", "wb") { |file| file.write(bytes) }
    end
    log("placed the starting save in world #{world.id}")
    true
  rescue => e
    log("could not place the starting save: #{e.class}: #{e.message}")
    false
  end

  # Reports whether a new player must be asked where to start before entering a world: the world
  # lets its players choose, and this PC has no save of the world yet.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @param choose [Boolean, nil] Whether the world lets its players choose, nil when unknown.
  # @return [Boolean] Whether the player must be asked.
  def self.ask_start?(world, choose)
    choose == true && new_player?(world)
  end

  # Reports whether a world's starting save must be fetched before entering it: the world has one,
  # and this PC has no save of the world yet.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @param start [String, nil] How far the world is with its starting save, nil when unknown.
  # @return [Boolean] Whether it must.
  def self.fetch?(world, start)
    start == "ready" && new_player?(world)
  end

  # Reports whether the player enters a world for the first time: this PC has no save of it yet.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [Boolean] Whether they do.
  def self.new_player?(world)
    world.latest_save.nil?
  end

  # Starts fetching a world's starting save into its folder; how it went follows as a directory action.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [Boolean] Whether the action started.
  def self.fetch(world)
    MGQ_Multiplayer::Player.share
    MGQ_Multiplayer::Link.function('mp_dir_fetch_start', 'pp').call(world.code + "\0", world.save_folder + "\0") == 1
  end

  # Checks that this game can load a fetched starting save, and throws it away when it cannot, so
  # the next entry fetches it again, after the missing mod was installed perhaps.
  #
  # Loading the system save quits the game when it fails, so it is checked before the world opens.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [String, nil] Why it cannot be loaded, nil when it can.
  def self.check(world)
    [SAVE_NAME, SYSTEM_NAME].each do |name|
      path = "#{world.save_folder}/#{name}"
      next unless File.exist?(path)

      File.open(path, "rb") { |file| Marshal.load(file) until file.eof? }
    end
    nil
  rescue => e
    log("the starting save of world #{world.id} cannot be loaded: #{e.class}: #{e.message}")
    discard(world)
    missing = e.message[MISSING_CLASS, 1]
    missing ? "The starting save needs a mod you do not have, one that adds #{missing}." : "The starting save could not be loaded."
  end

  # Deletes a fetched starting save's files from a world's folder.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  def self.discard(world)
    [SAVE_NAME, THUMBNAIL_NAME, SYSTEM_NAME].each do |name|
      path = "#{world.save_folder}/#{name}"
      File.delete(path) if File.exist?(path)
    end
  rescue => e
    log("could not delete the starting save: #{e.class}: #{e.message}")
  end
end

# The save screen, opened from the world screen to pick a new world's starting save or a player's
# own start in a world: the game's own list of saves, whose choice is handed back instead of loaded.
class Scene_MpStartSave < Scene_Load
  # Tells what the list is for.
  #
  # @return [String] The text.
  def help_window_text
    MGQ_MpSaveDistribution.help
  end

  # Hands the chosen save back to the world screen, if there is a save in that slot.
  def on_savefile_ok
    unless File.exist?(DataManager.make_filename(@index))
      Sound.play_buzzer
      return
    end

    Sound.play_ok
    MGQ_MpSaveDistribution.chosen = @index
    return_scene
  end
end
