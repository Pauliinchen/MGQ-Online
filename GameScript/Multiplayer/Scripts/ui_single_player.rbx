#----------------------------------------------------------------
#  ui_single_player.rbx
#
#  Changelog:
#      Paulinchen  2026-10-13: Created
#
#----------------------------------------------------------------

# The Mod Config group of single player, MGQ Online SP (MGQ_MpUi::SP_PREFIX): its rows in their
# order, the interface first (the Leader HUD and the raid bosses' bars, see ui_leader_hud.rbx and
# ui_raid_bar.rbx), then Raid Bosses (battles_raid_tiers.rbx), each kept by its own script. Once the
# player changed one in a game of their own outside a world, the map offers to start the game
# again: the game is first saved to RESUME_FILE through the game's own save, apart from every save
# slot, and the game started again loads it at its title screen and goes on where the player was,
# so nothing is lost. Inside a world the rows apply as they change, since a restart would leave it.
#
# It must work without any connection: the restart is the DLL's local mp_restart_game alone.
module MGQ_MpSinglePlayer
  # The game the player plays on, kept for the restart, as the game's own save writes it.
  RESUME_FILE = "#{MGQ_Multiplayer::MOD_DIR}\\Resume.rvdata2"

  # Where a game kept for a restart that could not be loaded, or that a new restart finds, is put
  # aside instead of lost, by the time it was put there.
  KEPT_FILE = "#{MGQ_Multiplayer::MOD_DIR}\\Resume %s.rvdata2"

  # The game's switch that holds the real game in memory while the Library replays a scene, during
  # which the game's own saves are off.
  LIBRARY_REPLAY_SWITCH = 443

  # The notification box's key of this script's messages.
  NOTICE_KEY = :single_player

  # What the box asks once an SP row changed.
  RESTART_QUESTION = "Start the game again so the MGQ Online SP settings apply cleanly? " \
                     "Your game is saved apart from your slots and goes on right here."

  # The box's yes and no choices.
  RESTART_CHOICES = ["Restart", "Later"]

  # What the player reads under Wine or Proton, where the game cannot start itself again.
  BY_HAND_TEXT = "Start the game again yourself: it goes on right where you are."

  # What the player reads when the game could not start itself again.
  FAILED_TEXT = "The game could not start itself again. The settings apply as they are."

  # What the player reads when the game could not be saved for the restart.
  SAVE_FAILED_TEXT = "The game could not be saved for the restart. The settings apply as they are."

  # The setting in Player.ini that keeps the slot the game last saved to or loaded from while the
  # game waits in RESUME_FILE, so the Save and Load screens' cursor stays on it after the restart.
  SLOT_SETTING = "resume_slot"

  # What the player reads when the game kept for the restart could not be loaded.
  RESUME_FAILED_TEXT = "The game kept for the restart could not be loaded. It is kept in %s."

  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "single player"

  # Whether a row differs from its value at the last offer, while the player plays a game of their own.
  @changed = false

  # Each row changed since the last offer with its value then, and with its value now, by key.
  @before = {}
  @now = {}

  # Whether the player plays a game: from the map on, until the title screen.
  @playing = false

  # Whether the game's make_filename names RESUME_FILE, see with_resume_file.
  @resume_file = false

  # Whether the title screen looked for the game kept for a restart since it opened.
  @resume_looked = false

  # Lists the group's rows in their order: each row's key, name, help, how it reads its value and
  # how it takes the value picked.
  #
  # @return [Array<Array>] The rows.
  def self.rows
    on_off = lambda { |on| on ? MGQ_MpLeaderHud::ON : MGQ_MpLeaderHud::OFF }
    [
      [MGQ_MpLeaderHud::SP_SHOWN_OPTION, MGQ_MpLeaderHud::SHOWN_OPTION_NAME, MGQ_MpLeaderHud::SP_SHOWN_OPTION_HELP,
       lambda { on_off.call(MGQ_MpLeaderHud.sp_shown?) }, lambda { |value| MGQ_MpLeaderHud.show_sp(value == MGQ_MpLeaderHud::ON) }],
      [MGQ_MpRaidBar::OPTIONS[:map], MGQ_MpRaidBar::OPTION_NAMES[:map], MGQ_MpRaidBar::OPTION_HELPS[:map],
       lambda { on_off.call(MGQ_MpRaidBar.shown?(:map)) }, lambda { |value| MGQ_MpRaidBar.show_bar(:map, value == MGQ_MpLeaderHud::ON) }],
      [MGQ_MpRaidBar::OPTIONS[:battle], MGQ_MpRaidBar::OPTION_NAMES[:battle], MGQ_MpRaidBar::OPTION_HELPS[:battle],
       lambda { on_off.call(MGQ_MpRaidBar.shown?(:battle)) }, lambda { |value| MGQ_MpRaidBar.show_bar(:battle, value == MGQ_MpLeaderHud::ON) }],
      [MGQ_MpRaidTiers::OPTION, MGQ_MpRaidTiers::OPTION_NAME, MGQ_MpRaidTiers::OPTION_HELP,
       lambda { on_off.call(MGQ_MpRaidTiers.single_player?) }, lambda { |value| MGQ_MpRaidTiers.choose(value == MGQ_MpLeaderHud::ON) }],
    ]
  end

  # Offers the group's rows in the Mod Config, kept in Player.ini, each change noted for the offer
  # to start the game again.
  def self.add_options
    added = rows.map do |key, name, help, read, write|
      MGQ_MpUi.add_option(key, name, help, lambda { [MGQ_MpLeaderHud::ON, MGQ_MpLeaderHud::OFF] }, read,
                          lambda { |value| changed(key, read.call, value, write) }, MGQ_MpUi::SP_PREFIX)
    end
    log(added.all? ? "added MGQ Online SP to the Mod Config" : "no MGQ Online SP in the Mod Config: it needs a Mod Config Remake that knows rows the mod keeps")
  end

  # Takes a row's value picked, noting a change made in a game of the player's own outside a world;
  # a row turned back to its value at the last offer counts as unchanged.
  #
  # @param key [Symbol] The row's key.
  # @param was [String] The row's value before.
  # @param value [String] The value picked.
  # @param write [Proc] Takes the value.
  def self.changed(key, was, value, write)
    write.call(value)
    return unless @playing && !MGQ_MpOverworldSync.in_world?

    @before[key] = was unless @before.key?(key)
    @now[key] = value
    @changed = @before.any? { |row, before| @now[row] != before }
  rescue => e
    log("taking a row's value failed: #{e.class}: #{e.message}")
  end

  # Notes that the player plays a game, as the map starts.
  def self.on_map_start
    @playing = true
  end

  # Notes that no game is played, at the title screen, and forgets a change made in the last one.
  def self.on_title_start
    @playing = false
    @resume_looked = false
    settle
  end

  # Takes the rows as they are now as the values the next change is compared with.
  def self.settle
    @changed = false
    @before = {}
    @now = {}
  end

  # Offers to start the game again once a row changed, on the map while nothing runs there. Called
  # by the map every frame no scene change is in the way.
  def self.on_map
    return unless @changed && quiet? && !MGQ_MpUi::Confirm.open?
    unless MGQ_Multiplayer.available?
      settle
      return log("no restart offered: the DLL that starts the game again is missing")
    end

    settle if MGQ_MpUi::Confirm.ask(RESTART_QUESTION, RESTART_CHOICES) { |yes| answered(yes) }
  rescue => e
    log_once(:on_map, "offering a restart failed: #{e.class}: #{e.message}")
  end

  # Takes the answer to the offer: a restart, unless the map got busy while the box showed, which
  # then asks again once it is free, since a save in the middle of an event would skip its command.
  #
  # @param yes [Boolean] Whether the player picked Restart.
  def self.answered(yes)
    return log("the player starts the game again later") unless yes
    return restart if quiet?

    @changed = true
    log("the map got busy while the box showed, so the restart is offered again once it is free")
  end

  # Reports whether the map is free for the offer and the save it takes: outside a world, no event
  # runs, no message shows, the player is not on the move between maps, and the game's own saves are
  # allowed, neither turned off by the game, by a Library replay nor by parked mods.
  #
  # @return [Boolean] Whether it is.
  def self.quiet?
    !MGQ_MpOverworldSync.in_world? && !$game_map.interpreter.running? && !$game_message.busy? && !$game_player.transfer? && saving_allowed?
  end

  # Reports whether the game's own saves are allowed now.
  #
  # @return [Boolean] Whether they are.
  def self.saving_allowed?
    return false if $game_system.save_disabled || $game_switches[LIBRARY_REPLAY_SWITCH]

    !(defined?(MGQ_MpModParking) && MGQ_MpModParking.respond_to?(:saving_off?) && MGQ_MpModParking.saving_off?)
  end

  # Tells the player a message in the notification box, which also shows outside a world.
  #
  # @param text [String] The message.
  def self.notice(text)
    MGQ_MpNotices.message(NOTICE_KEY, text) if defined?(MGQ_MpNotices)
  end

  # Saves the game apart from every save slot and starts the game again, which then goes on from it.
  # A save that fails starts nothing, so the player plays on as they were.
  def self.restart
    return notice(SAVE_FAILED_TEXT) unless save_resume

    case MGQ_Multiplayer::Link.function('mp_restart_game').call
    when 1
      log("starting the game again, which goes on from #{RESUME_FILE}")
      SceneManager.exit
    when 2
      log("the game cannot start itself again under Wine, so the player does; it goes on from #{RESUME_FILE}")
      msgbox(BY_HAND_TEXT)
      SceneManager.exit
    else
      forget_resume
      log("the game could not start itself again, so it plays on")
      notice(FAILED_TEXT)
    end
  rescue => e
    forget_resume
    log("starting the game again failed: #{e.class}: #{e.message}")
  end

  # Saves the game to RESUME_FILE through the game's own save, keeping the slot the game last
  # saved to or loaded from in SLOT_SETTING; a game kept there before goes aside first.
  #
  # The save counts as none of the player's, as the game's autosave does, since events read the
  # number of saves.
  #
  # @return [Boolean] Whether it was saved.
  def self.save_resume
    raise "#{RESUME_FILE} could not be put aside" if File.exist?(RESUME_FILE) && keep_aside == RESUME_FILE
    slot = DataManager.last_savefile_index
    count = $game_system.save_count
    MGQ_Multiplayer::Player.store(SLOT_SETTING, slot)
    $game_system.instance_variable_set(:@save_count, count - 1)
    with_resume_file { DataManager.save_game_without_rescue(slot) }
    log("saved the game to #{RESUME_FILE} for the restart")
    true
  rescue => e
    $game_system.instance_variable_set(:@save_count, count) if count
    log("saving the game for the restart FAILED: #{e.class}: #{e.message}")
    false
  end

  # Goes on from the game kept for a restart, once at the title screen's first frame: loads it
  # through the game's own load, finishes it as Continue does and removes it. A game that cannot be
  # loaded stays, and the player reads where.
  #
  # @param scene [Scene_Title] The title screen.
  def self.resume(scene)
    return if @resume_looked || scene.scene_changing? || title_busy?

    @resume_looked = true
    return unless File.exist?(RESUME_FILE)

    with_resume_file { DataManager.load_game_without_rescue(resume_slot) }
    Scene_Load.new.on_load_success
    forget_resume
    log("went on from the game kept for the restart")
  rescue => e
    kept = keep_aside
    log("going on from #{RESUME_FILE} FAILED, kept as #{kept}: #{e.class}: #{e.message}")
    msgbox(format(RESUME_FAILED_TEXT, kept))
  end

  # Reports whether the title screen is busy with what comes before a game of the player's own: a
  # world open or starting its new game, the update offer, or mods parked for a world that the title
  # screen puts back and restarts for.
  #
  # @return [Boolean] Whether it is.
  def self.title_busy?
    world = MGQ_MpWorld
    return true if world.open? || world.new_game_pending? || (defined?(world::UpdateOffer) && world::UpdateOffer.shown?)

    parking = defined?(MGQ_MpModParking) ? MGQ_MpModParking : nil
    parking ? (parking.title_busy? || parking.restart_due?) : false
  end

  # Puts the game kept in RESUME_FILE aside under KEPT_FILE, so it is neither lost nor loaded again.
  #
  # @return [String] Where it went, RESUME_FILE when it could not be moved.
  def self.keep_aside
    stamp = Time.now.strftime("%Y-%m-%d %H-%M-%S")
    kept = format(KEPT_FILE, stamp)
    number = 1
    kept = format(KEPT_FILE, "#{stamp} #{number += 1}") while File.exist?(kept)
    File.rename(RESUME_FILE, kept)
    log("put the game kept for a restart aside as #{kept}")
    kept
  rescue => e
    log("putting #{RESUME_FILE} aside failed: #{e.class}: #{e.message}")
    RESUME_FILE
  end

  # Tells the slot the game last saved to or loaded from before the restart, see SLOT_SETTING: a
  # number for a slot, the name of an autosave, 0 when none was kept.
  #
  # @return [Integer, String] The slot.
  def self.resume_slot
    slot = MGQ_Multiplayer::Player.setting(SLOT_SETTING).to_s
    return 0 if slot.empty?

    slot =~ /\A\d+\z/ ? slot.to_i : slot
  end

  # Removes the game kept for a restart.
  def self.forget_resume
    File.delete(RESUME_FILE) if File.exist?(RESUME_FILE)
  rescue => e
    log("removing #{RESUME_FILE} failed: #{e.class}: #{e.message}")
  end

  # Runs the game's save or load with its make_filename naming RESUME_FILE.
  #
  # @return [Object] What the block returns.
  def self.with_resume_file
    @resume_file = true
    yield
  ensure
    @resume_file = false
  end

  # Finds the file the game's save or load uses for a slot: RESUME_FILE inside with_resume_file.
  #
  # @param own [String] The game's own file of the slot.
  # @return [String] The file.
  def self.filename(own)
    @resume_file ? RESUME_FILE : own
  end
end

# The Mod Config rows, through ui.rbx.

begin
  MGQ_MpSinglePlayer.add_options
rescue => e
  MGQ_MpSinglePlayer.log("Mod Config rows FAILED: #{e.class}: #{e.message}")
end

# Game hooks, through core_hooks.rbx.

begin
  MGQ_MpHooks.after(Scene_Map, :start, "ui_single_player") { MGQ_MpSinglePlayer.on_map_start }
  MGQ_MpHooks.after(Scene_Map, :update_scene, "ui_single_player") { MGQ_MpSinglePlayer.on_map unless scene_changing? }
  MGQ_MpHooks.before(Scene_Title, :start, "ui_single_player") { MGQ_MpSinglePlayer.on_title_start }
  MGQ_MpHooks.after(Scene_Title, :update, "ui_single_player") { MGQ_MpSinglePlayer.resume(self) }

  # The translation's plugins load after the Patch folder, so the save's file name is wrapped as
  # the game starts running.
  MGQ_MpHooks.before(SceneManager.singleton_class, :run, "ui_single_player") do
    MGQ_MpHooks.around(DataManager.singleton_class, :make_filename, "ui_single_player") do |_manager, _args, original|
      MGQ_MpSinglePlayer.filename(original.call)
    end
  end
rescue => e
  MGQ_MpSinglePlayer.log("hooks FAILED: #{e.class}: #{e.message}")
end
