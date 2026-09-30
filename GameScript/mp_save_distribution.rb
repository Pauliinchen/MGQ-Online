#----------------------------------------------------------------
#  mp_save_distribution.rb
#
#  Changelog:
#      Paulinchen  2026-09-30: Created
#
#----------------------------------------------------------------

# A world's starting save: one of the creator's own saves, with their system save, which every new
# player of the world starts from instead of the opening. The creator picks it when making the
# world, and it can never be changed. The relay keeps it encrypted with a key from the world's
# token; a new player's game fetches it into the world's folder before entering the world for the
# first time, where it is the world's first save.
#
# mp_world.rb, which loads later, calls it from the world screen. It must never interrupt the game,
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

  # Writes a line to the Multiplayer mod's InGame.log.
  #
  # @param message [String] The line.
  def self.log(message)
    MGQ_Multiplayer::Log.write("starting save: #{message}")
  rescue
  end

  # Opens the save screen to pick the starting save of a new world.
  def self.choose
    @chosen = nil
    SceneManager.call(Scene_MpStartSave)
  end

  # Keeps the save the player picked.
  #
  # @param index [Integer] The save's index, as DataManager takes it.
  def self.chosen=(index)
    @chosen = index
  end

  # Hands out the save the player picked, once.
  #
  # @return [Integer, nil] The save's index, nil when the player left the save screen without one.
  def self.take_chosen
    index = @chosen
    @chosen = nil
    index
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

  # Writes the files as Multiplayer/Multiplayer.dll takes them.
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

  # Reports whether a world's starting save must be fetched before entering it: the world has one,
  # and this PC has no save of the world yet.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @param listed [MGQ_MpWorld::Directory::ListedWorld, nil] The world in the directory.
  # @return [Boolean] Whether it must.
  def self.fetch?(world, listed)
    !listed.nil? && listed.start == "ready" && world.latest_save.nil?
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

# The save screen, opened from the world screen to pick a new world's starting save: the game's own
# list of saves, whose choice is handed back instead of loaded.
class Scene_MpStartSave < Scene_Load
  # Tells what the list is for.
  #
  # @return [String] The text.
  def help_window_text
    "Choose the save every new player of the world starts from."
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
