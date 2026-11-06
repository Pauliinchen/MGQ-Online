#----------------------------------------------------------------
#  world_save_export.rbx
#
#  Changelog:
#      Paulinchen  2026-11-06: Added Copy to my game to the game's menu through a patch of the UI layer, its message the layer's
#      Paulinchen  2026-11-01: Added Copy to my game to the game's menu through the Mod Framework, showing how it went in its message
#      Paulinchen  2026-10-12: Read the menu's commands through MGQ_MpGame and left them alone when the menu has none
#      Paulinchen  2026-10-08: Closed with the numpad's 0 through MGQ_MpUi.cancel?
#      Paulinchen  2026-10-07: Registered the menu's hooks through core_hooks.rbx
#                            - Took the notice's depth from MGQ_MpUi
#                            - Logged why a save is not copied and the thumbnail copied with it
#      Paulinchen  2026-10-04: Renamed from mp_save_export.rbx
#      Paulinchen  2026-10-03: Built the notice on Window_MpInfo of ui.rbx
#                            - Logged through MGQ_MpLog
#      Paulinchen  2026-10-02: Created
#
#----------------------------------------------------------------

# Copies a world's latest save into the player's own game, into the first free slot of the game's
# Save folder, so what they played in a world goes on in single player. Only the save and its
# thumbnail come along: the player's own Library, medals and affection stay as they are.
#
# The world screen (world_screen.rbx) offers it on a world the player has played, and the game's
# menu while a world is open. It must never interrupt the game, so every entry point rescues.
module MGQ_MpSaveExport
  # The menu's command while a world is open, and the title of the message that shows how it went.
  MENU_COMMAND = "Copy to my game"

  # The menu command's id, which other mods' patches name as #mgq_online_save_export.
  MENU_ID = :mgq_online_save_export

  # What a save file's thumbnail is named after, its extension swapped.
  SAVE_EXTENSION = /\.rvdata2\z/i

  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "save export"

  # Copies a world's latest save, an autosave included, into the first free slot of the player's
  # own saves, with its thumbnail.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [String] What happened, for the player.
  def self.export(world)
    source = world.latest_save_file
    unless source
      log("not copying a save of world #{world.id} (#{world.name}): it has none here")
      return "You have no save of #{world.name} yet. Save in the world first."
    end

    saved = File.mtime(source).strftime("%Y-%m-%d %H:%M")
    MGQ_MpWorld::Files.unmapped do
      index = free_slot
      unless index
        log("not copying #{source} of world #{world.id}: all #{DataManager.savefile_max} slots of the player's own game hold a save")
        return "Your own game has no free save slot. Delete one of your saves first."
      end

      target = DataManager.make_filename(index)
      copy(source, target)
      thumbnail = source.sub(SAVE_EXTENSION, ".png")
      with_thumbnail = File.exist?(thumbnail) && DataManager.respond_to?(:make_thumbnailname)
      copy(thumbnail, DataManager.make_thumbnailname(index)) if with_thumbnail
      log("copied #{source} (saved #{saved}) of world #{world.id} (#{world.name}) into slot #{index + 1}, #{target}, #{with_thumbnail ? 'with' : 'without'} its thumbnail")
      "Your save of #{world.name} from #{saved} is now save #{index + 1} of your own game."
    end
  rescue => e
    log("could not copy the save of world #{world.id}: #{e.class}: #{e.message}")
    "The save could not be copied into your own game."
  end

  # Finds the first slot of the player's own saves without a save.
  #
  # @return [Integer, nil] The slot's index as DataManager takes it, nil when every slot holds one.
  def self.free_slot
    (0...DataManager.savefile_max).find { |index| !File.exist?(DataManager.make_filename(index)) }
  end

  # Copies a file, making its folder first.
  #
  # @param source [String] The file.
  # @param target [String] Where it goes.
  def self.copy(source, target)
    folder = File.dirname(target)
    Dir.mkdir(folder) unless File.directory?(folder)
    bytes = File.open(source, "rb") { |file| file.read }
    File.open(target, "wb") { |file| file.write(bytes) }
  end

  # Adds Copy to my game to the game's menu, before Save: only while a world is open, and greyed
  # out until the player saved in it. Picking it shows how the copy went in a message, and the
  # framework gives the menu back once the message closed.
  def self.add_to_menu
    Mod_Framework::UI.patch "Window_MenuCommand" do |menu|
      menu.before "#save" do
        command MGQ_MpSaveExport::MENU_COMMAND, id: MGQ_MpSaveExport::MENU_ID, if: -> { MGQ_MpWorld.open? }, enabled: -> { MGQ_MpSaveExport.saved? },
                                                on_click: -> { Mod_Framework::UI.message(MGQ_MpSaveExport.export_open_world, title: MGQ_MpSaveExport::MENU_COMMAND) }
      end
    end
  end

  # Tells whether the player saved in the open world, which the menu's command needs.
  #
  # @return [Boolean] Whether they did.
  def self.saved?
    MGQ_MpWorld.open? && !MGQ_MpWorld.world.latest_save.nil?
  end

  # Copies the open world's latest save from the game's menu.
  #
  # @return [String] What happened, for the player.
  def self.export_open_world
    log("Copy to my game chosen in the menu")
    MGQ_MpWorld.open? ? export(MGQ_MpWorld.world) : "No world is open."
  end
end

begin
  MGQ_MpSaveExport.add_to_menu
rescue => e
  MGQ_MpSaveExport.log("menu command FAILED: #{e.class}: #{e.message}")
end
