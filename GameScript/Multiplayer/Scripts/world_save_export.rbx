#----------------------------------------------------------------
#  world_save_export.rbx
#
#  Changelog:
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
# The world screen (world.rbx) offers it on a world the player has played, and the game's menu
# while a world is open. It must never interrupt the game, so every entry point rescues.
module MGQ_MpSaveExport
  # The menu's command while a world is open.
  MENU_COMMAND = "Copy to my game"

  # What a save file's thumbnail is named after, its extension swapped.
  SAVE_EXTENSION = /\.rvdata2\z/i

  # Reports whether the hooks can be installed.
  #
  # A second copy of this script would wrap the same methods under the same names, and each hook
  # would then call itself until the stack overflows.
  #
  # @return [Boolean] false when the hooks are in place already.
  def self.hookable?
    !Scene_Menu.method_defined?(:mgq_mp_save_export_update)
  end

  extend MGQ_MpLog

  # What starts this script's lines in the mod's InGame.log.
  LOG_TAG = "save export"

  # Copies a world's latest save, an autosave included, into the first free slot of the player's
  # own saves, with its thumbnail.
  #
  # @param world [MGQ_MpWorld::World] The world on this PC.
  # @return [String] What happened, for the player.
  def self.export(world)
    source = world.latest_save_file
    return "You have no save of #{world.name} yet. Save in the world first." unless source

    saved = File.mtime(source).strftime("%Y-%m-%d %H:%M")
    MGQ_MpWorld::Files.unmapped do
      index = free_slot
      return "Your own game has no free save slot. Delete one of your saves first." unless index

      copy(source, DataManager.make_filename(index))
      thumbnail = source.sub(SAVE_EXTENSION, ".png")
      copy(thumbnail, DataManager.make_thumbnailname(index)) if File.exist?(thumbnail) && DataManager.respond_to?(:make_thumbnailname)
      log("copied #{source} of world #{world.id} into slot #{index + 1}")
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
    MGQ_MpWorld.open? ? export(MGQ_MpWorld.world) : "No world is open."
  end
end

# What copying a save from the game's menu ended with, in the middle of the screen until OK or
# Cancel is pressed.
class Window_MpSaveExportNotice < Window_MpInfo
  # What the notice says below the result.
  CLOSE_HINT = "Press OK to go on."

  # Layer above the menu's windows.
  Z = 300

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

# Game hooks of this script alone.
#
# Each wraps a game method: the original runs first, and the mod's part never raises.

if MGQ_MpSaveExport.hookable?
  begin
    class Window_MenuCommand
      alias mgq_mp_save_export_add_original_commands add_original_commands

      # Lists the game's own extra commands, then Copy to my game while a world is open.
      def add_original_commands
        mgq_mp_save_export_add_original_commands
        MGQ_MpSaveExport.add_menu_command(self)
      end
    end

    class Scene_Menu
      alias mgq_mp_save_export_create_command_window create_command_window

      # Creates the menu's commands, Copy to my game among them.
      def create_command_window
        mgq_mp_save_export_create_command_window
        @command_window.set_handler(:mgq_mp_save_export, method(:mgq_mp_save_export_command))
      end

      # Copies the open world's latest save and shows how it went.
      def mgq_mp_save_export_command
        @mgq_mp_save_export_notice = Window_MpSaveExportNotice.new(MGQ_MpSaveExport.export_open_world)
      rescue => e
        MGQ_MpSaveExport.log("menu export failed: #{e.class}: #{e.message}")
        @command_window.activate
      end

      alias mgq_mp_save_export_update update

      # Updates the menu, then closes the notice once the player pressed OK or Cancel.
      def update
        mgq_mp_save_export_update
        return unless @mgq_mp_save_export_notice && @mgq_mp_save_export_notice.closed?

        @mgq_mp_save_export_notice.dispose
        @mgq_mp_save_export_notice = nil
        @command_window.activate
      end

      alias mgq_mp_save_export_terminate terminate

      # Takes the notice off the screen, then ends the menu.
      def terminate
        @mgq_mp_save_export_notice.dispose if @mgq_mp_save_export_notice
        mgq_mp_save_export_terminate
      end
    end
  rescue => e
    MGQ_MpSaveExport.log("menu hooks FAILED: #{e.class}: #{e.message}")
  end
end
