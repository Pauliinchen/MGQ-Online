#----------------------------------------------------------------
#  world_save_export.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Registered the menu's hooks through core_hooks.rbx instead of wraps of this script
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
  # The menu's command while a world is open.
  MENU_COMMAND = "Copy to my game"

  # What a save file's thumbnail is named after, its extension swapped.
  SAVE_EXTENSION = /\.rvdata2\z/i

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
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

  # Adds the menu's command while a world is open, greyed out until the player saved in it.
  #
  # @param window [Window_MenuCommand] The game's menu.
  def self.add_menu_command(window)
    return unless MGQ_MpWorld.open?

    window.add_command(MENU_COMMAND, :mgq_mp_save_export, !MGQ_MpWorld.world.latest_save.nil?)
  rescue => e
    log("menu command failed: #{e.class}: #{e.message}")
  end

  # Copies the open world's latest save from the game's menu.
  #
  # @return [String] What happened, for the player.
  def self.export_open_world
    log("Copy to my game chosen in the menu")
    MGQ_MpWorld.open? ? export(MGQ_MpWorld.world) : "No world is open."
  end

  # Copies the open world's latest save from the game's menu and opens the notice that shows how it
  # went; when the notice cannot open, the menu's commands take input again.
  #
  # @param scene [Scene_Menu] The menu.
  # @return [Window_MpSaveExportNotice, nil] The notice, nil when it could not open.
  def self.open_notice(scene)
    Window_MpSaveExportNotice.new(export_open_world)
  rescue => e
    log("menu export failed: #{e.class}: #{e.message}")
    MGQ_MpGame.get(scene, :command_window).activate
    nil
  end
end

# What copying a save from the game's menu ended with, in the middle of the screen until OK or
# Cancel is pressed.
class Window_MpSaveExportNotice < Window_MpInfo
  # What the notice says below the result.
  CLOSE_HINT = "Press OK to go on."

  # Layer above the menu's windows.
  Z = MGQ_MpUi::Z[:wheels]

  # Creates the notice in the middle of the screen.
  #
  # @param text [String] What happened.
  def initialize(text)
    super()
    self.y = (Graphics.height - height) / 2
    self.z = Z
    show([text, CLOSE_HINT])
    @frames = 0
  end

  # Tells whether the player closed the notice, ignoring the press that opened it.
  #
  # @return [Boolean] Whether OK or Cancel was pressed after the first frame.
  def closed?
    @frames += 1
    @frames > 1 && (Input.trigger?(:C) || Input.trigger?(:B))
  end
end

# Game hooks, through core_hooks.rbx.

begin
  # After the game's own extra commands, Copy to my game while a world is open.
  MGQ_MpHooks.after(Window_MenuCommand, :add_original_commands, "world_save_export") { MGQ_MpSaveExport.add_menu_command(self) }

  # After the menu's commands are made, Copy to my game gets its handler.
  MGQ_MpHooks.after(Scene_Menu, :create_command_window, "world_save_export") do
    @command_window.set_handler(:mgq_mp_save_export, lambda { @mgq_mp_save_export_notice = MGQ_MpSaveExport.open_notice(self) })
  end

  # After the menu's update, the notice closes once the player pressed OK or Cancel.
  MGQ_MpHooks.after(Scene_Menu, :update, "world_save_export") do
    if @mgq_mp_save_export_notice && @mgq_mp_save_export_notice.closed?
      @mgq_mp_save_export_notice.dispose
      @mgq_mp_save_export_notice = nil
      @command_window.activate
    end
  end

  # Before the menu ends, the notice goes off the screen.
  MGQ_MpHooks.before(Scene_Menu, :terminate, "world_save_export") do
    @mgq_mp_save_export_notice.dispose if @mgq_mp_save_export_notice
  end
rescue => e
  MGQ_MpSaveExport.log("menu hooks FAILED: #{e.class}: #{e.message}")
end
