#----------------------------------------------------------------
#  world_mods_parking.rbx
#
#  Changelog:
#      Paulinchen  2026-10-23: Left what entering a world needs of the parked mods to the DLL's steps into a world
#                            - Left which scripts a world turns off, when they move and what the player is told to the DLL's parking topics
#                            - Started the game again with the mods parked under Wine or Proton too, dropping the restart by hand
#                            - Deleted the check for the options dump
#      Paulinchen  2026-10-22: Checked a world's mods again only once the list carries them
#      Paulinchen  2026-10-10: Told the player on the title screen how many mods a restore sent to Parked mods/Conflicts
#                            - Refused saving outside a world while the game runs without the player's other mods
#                            - Kept the game out of a world that turns off scripts behind a link to another drive, and counted those as on
#                            - Kept the parked state read last when the DLL could not read its journal
#                            - Added texts for other mods that could not be turned off or back on for a world's downloaded mods
#      Paulinchen  2026-10-09: Created
#
#----------------------------------------------------------------

# Turning other mods off: a world that turns other mods off is played only with the mods it names,
# the mods the relay's catalog marks personal, and the scripts every player has. Before the game
# enters such a world, the DLL moves ("parks") the scripts of every other mod out of the Patch
# folder into the game folder's Parked mods, and the game starts again and enters the world. The
# mods come back as the player leaves the world for the title screen, through the DLL's watchdog
# after a crash, and at the next start for whatever is still parked.
#
# The DLL decides which scripts and when (ParkingSession, topics parking.*); this script hands it
# the world screen's and the title screen's events and shows the title screen's box.
module MGQ_MpModParking
  extend MGQ_MpLog

  # What starts this script's lines in the log.
  LOG_TAG = "mod parking"

  # The topic that lists the player's mods a world turns off.
  PLAN_TOPIC = "parking.plan"

  # The topic that starts the game again to enter a world once it is back.
  REJOIN_TOPIC = "parking.rejoin"

  # The topic that takes the world to enter again after a restart.
  TAKE_REJOIN_TOPIC = "parking.take_rejoin"

  # The topic of a title screen that starts, before the world closes.
  TITLE_STARTED_TOPIC = "parking.title_started"

  # The topic of a title screen that started, after the world closed.
  TITLE_LEFT_TOPIC = "parking.title_left"

  # The topic of a world entered.
  ENTERED_TOPIC = "parking.entered"

  # The topic of a start that entered a world again and ended without entering it.
  GIVE_UP_TOPIC = "parking.give_up"

  # The topic that starts the game again once the title screen told why.
  RESTART_NOW_TOPIC = "parking.restart_now"

  # The topic of the title screen's notice the player closed.
  NOTICE_CLOSED_TOPIC = "parking.notice_closed"

  # The topic that has the title screen tell something.
  TELL_TOPIC = "parking.tell"

  # The topic of the updater that started.
  UPDATE_STARTED_TOPIC = "parking.update_started"

  # The topic that answers the state the script keeps a copy of.
  STATE_TOPIC = "parking.state"

  # The topic that takes the relay's word on the open world's rule.
  RULE_TOPIC = "parking.rule"

  # The topic that takes what a player must be told before leaving a world that now turns their mods off.
  TAKE_KICK_TOPIC = "parking.take_kick"

  # Frames the title screen tells why the game starts again before it does, three seconds.
  RESTART_FRAMES = 180

  # Frames a player in a world that now turns other mods off is told so before the game goes to the
  # title screen, once the map is free, five seconds.
  KICK_FRAMES = 300

  # The key of this script's lines in the notification box.
  NOTICE_KEY = :mod_parking

  # What the box on the title screen is called while the mods come back.
  BACK_TITLE = "Turning your mods back on"

  # The hint of the box while the game is about to start again.
  RESTART_HINT = "The game starts again in a moment."

  # The hint of the box while it only tells something.
  NOTICE_HINT = "Enter, Esc or Numpad 0: close"

  # What the state reads before the DLL answered.
  IDLE_STATE = { "holding" => false, "due" => nil, "notice" => nil, "saving_off" => false }

  # Tells whether the DLL can park and restore.
  #
  # @return [Boolean] Whether the mod's DLL is installed.
  def self.usable?
    MGQ_Multiplayer.available?
  end

  # Entering a world.

  # Lists the player's mods a world turns off (topic parking.plan).
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Array<Array>, nil] Each mod's name and how many of its scripts, none for a world that
  #   allows other mods; nil while they are unknown.
  def self.turned_off_mods(listed)
    return [] unless listed.other_mods_off

    plan = answer(PLAN_TOPIC, "mods" => listed.mods.to_s, "off" => true)
    plan && plan["plan"] ? plan["mods"] : nil
  end

  # Starts the game again to enter a world once it is back (topic parking.rejoin), the one way the
  # world is entered again after a restart for its mods.
  #
  # @param world_id [String] The world.
  # @return [Symbol] :restarting when the game closes now, :failed when it stays open.
  def self.rejoin(world_id)
    told = answer(REJOIN_TOPIC, "world" => world_id.to_s)
    told && told["restarting"] ? :restarting : :failed
  end

  # Takes the world the game should enter again after a restart, once.
  #
  # @return [String, nil] The world's id, nil when there is none.
  def self.take_rejoin
    MGQ_Multiplayer::Bridge.call(TAKE_REJOIN_TOPIC)
  end

  # The start after a restart, and the way back to the title screen.

  # Tells whether the game started again to enter a world with its mods parked, and has not
  # entered it yet.
  #
  # @return [Boolean] Whether it has.
  def self.holding?
    state["holding"] == true
  end

  # Notes that a world was entered, which ends the hold, and has the DLL check the world against a
  # list fetched now.
  def self.entered
    world = MGQ_MpWorld.world
    take(answer(ENTERED_TOPIC, "world" => world && world.directory_id, "name" => world ? world.name.to_s : ""))
  end

  # Puts the parked mods back once the start that entered a world again ended without entering it,
  # and starts the game again on the title screen.
  #
  # @param reason [String, nil] Why the world was not entered, for the box on the title screen.
  def self.give_up(reason = nil)
    take(answer(GIVE_UP_TOPIC, "reason" => reason && reason.to_s))
  end

  # Puts back what a game that closed while mods were parked left parked, once a session, and
  # counts the title screens. Called as the title screen starts, before MGQ_MpWorld closes the
  # world.
  def self.title_started
    take(answer(TITLE_STARTED_TOPIC)) if usable?
  end

  # Puts the parked mods back as the game returned to the title screen, as the DLL decides. Called
  # by MGQ_MpWorld as the title screen starts, after it closed the world.
  #
  # @param left_world [Boolean] Whether the game left a world for the title screen.
  def self.on_title_start(left_world = false)
    take(answer(TITLE_LEFT_TOPIC, "left_world" => left_world ? true : false)) if usable?
  end

  # Puts the parked mods back once the updater started, which waits for this game to close and then
  # starts it again itself.
  def self.restore_for_update
    take(answer(UPDATE_STARTED_TOPIC)) if usable?
  end

  # Tells whether the title screen is about to start the game again, or tells the player something,
  # which keeps the other scripts from opening the world screen meanwhile.
  #
  # @return [Boolean] Whether it is.
  def self.title_busy?
    !state["due"].nil? || !state["notice"].nil?
  end

  # Tells whether the title screen is about to start the game again.
  #
  # @return [Boolean] Whether it is.
  def self.restart_due?
    !state["due"].nil?
  end

  # Shows the box on the title screen and starts the game again once its time ran out, or closes a
  # notice once the player confirms it. Called by the title screen every frame.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    return unless title_busy?

    show_box(scene) unless @box_shown
    return follow_notice if state["notice"] && !state["due"]

    @frames = (@frames || RESTART_FRAMES) - 1
    restart_now if @frames <= 0
  rescue => e
    log("the title screen's box failed: #{e.class}: #{e.message}")
    hide_box
    @state = IDLE_STATE
  end

  # Shows the box and takes the input from the title's commands.
  #
  # @param scene [Scene_Title] The title screen.
  def self.show_box(scene)
    @scene = scene
    @box ||= Sprite_MpMessageBox.new
    @frames = RESTART_FRAMES
    state["due"] ? @box.show(BACK_TITLE, state["due"], RESTART_HINT) : @box.show(BACK_TITLE, state["notice"], NOTICE_HINT)
    @box_shown = true
    commands = MGQ_MpGame.get(scene, :command_window)
    commands.deactivate if commands && !commands.disposed?
    MGQ_Multiplayer::Capture.start(:mod_parking)
    # Windows keeps a click until it is asked for, so one from before the box would close it.
    MGQ_Multiplayer::Mouse.clicked?
  end

  # Closes the notice once the player confirms it, clicks or cancels.
  def self.follow_notice
    clicked = MGQ_Multiplayer::Mouse.clicked?
    return unless MGQ_Multiplayer::Capture.trigger?(:C) || MGQ_MpUi.cancel? || clicked

    Sound.play_cancel
    take(answer(NOTICE_CLOSED_TOPIC))
    hide_box
    commands = @scene && MGQ_MpGame.get(@scene, :command_window)
    commands.activate if commands && !commands.disposed?
  end

  # Starts the game again for the mods put back, or shows why it cannot.
  def self.restart_now
    @box_shown = false
    told = take(answer(RESTART_NOW_TOPIC))
    SceneManager.exit if told && told["restarting"]
  end

  # Takes the box off the screen. Called as the title screen ends.
  def self.hide_box
    @box_shown = false
    MGQ_Multiplayer::Capture.stop(:mod_parking)
    return unless @box

    @box.dispose
    @box = nil
  rescue => e
    log("closing the title screen's box failed: #{e.class}: #{e.message}")
  end

  # Saving without the other mods.

  # Tells whether saving is off: outside a world, while this session runs without some of the
  # player's mods, as the DLL tells.
  #
  # @return [Boolean] Whether it is.
  def self.saving_off?
    return false if !usable? || MGQ_MpWorld.open?

    state["saving_off"] == true
  end

  # Refuses a save while saving is off, see saving_off?, and tells the player of a save they made.
  # Called by the game's saves.
  #
  # @param auto [Boolean] Whether it is the autosave, which the player did not ask for.
  # @return [Boolean] Whether the save goes on.
  def self.save_allowed?(auto)
    return true unless saving_off?

    log("refused #{auto ? 'the autosave' : 'a save'}: no world is open and the game runs without the player's other mods")
    MGQ_MpNotices.message(NOTICE_KEY, state["save_text"].to_s) if !auto && defined?(MGQ_MpNotices)
    false
  rescue => e
    log("checking whether saving is off failed, saving: #{e.class}: #{e.message}")
    true
  end

  # A world that turns other mods off now.

  # Takes the relay's word that the open world's creator or an admin changed whether it turns other
  # mods off, or its mods: a game that now has mods to turn off goes to the title screen, from
  # where the player enters again, parking them.
  #
  # @param message [Hash] The push: MGQ_MpOverworldSync::MODS_RULE_FIELD with "1" or "0", the
  #   world's mods under "mods", marked :relay by overworld_sync.rbx.
  def self.pushed(message)
    return log("ignored a mods rule push not from the relay") unless message[:relay]

    mods = message["mods"].to_s
    world = MGQ_MpWorld.world
    told = answer(RULE_TOPIC, "value" => message[MGQ_MpOverworldSync::MODS_RULE_FIELD].to_s, "mods" => mods, "open" => MGQ_MpWorld.open? ? true : false,
                              "world" => world && world.directory_id, "name" => world ? world.name.to_s : "")
    return unless told && told["taken"]

    MGQ_MpWorldMods.take_mods(mods)
    kick(told["kick"])
  rescue => e
    log("taking the relay's mods rule failed: #{e.class}: #{e.message}")
  end

  # Tells the player that the world now turns other mods off, and takes the game to the title
  # screen once the time ran out and the player is free on the map. Called every frame of every
  # scene.
  def self.tick
    kick(MGQ_Multiplayer::Bridge.call(TAKE_KICK_TOPIC)) if usable? && MGQ_MpWorld::Changes.take?(MGQ_MpWorld::Changes::PARKING)
    return unless @kick

    unless MGQ_MpWorld.open?
      @kick = nil
      return
    end

    unless @kick[:told]
      @kick[:told] = true
      MGQ_MpNotices.message(NOTICE_KEY, @kick[:text], KICK_FRAMES) if defined?(MGQ_MpNotices)
    end
    @kick[:frames] -= 1
    return if @kick[:frames] > 0 || !MGQ_MpOverworldSync.map_free?

    leave_world
  rescue => e
    log_once(:tick, "tick failed: #{e.class}: #{e.message}")
  end

  # Starts telling a player in the open world that it now turns their mods off.
  #
  # @param text [String, nil] What they are told, nil for nothing.
  def self.kick(text)
    @kick = { :text => text, :frames => KICK_FRAMES, :told => false } if text && MGQ_MpWorld.open?
  end

  # Takes the game to the title screen, which closes the world, and has it tell why there.
  def self.leave_world
    text = @kick[:text]
    @kick = nil
    log("going to the title screen: #{text}")
    take(answer(TELL_TOPIC, "text" => text))
    scene = SceneManager.scene
    scene.fadeout_all if scene.respond_to?(:fadeout_all)
    SceneManager.goto(Scene_Title)
  end

  # Talking to the DLL.

  # Reads the state the DLL keeps, asked once and then kept from the answers.
  #
  # @return [Hash] "holding", "due", "notice", "saving_off" and "save_text".
  def self.state
    @state ||= (usable? && MGQ_Multiplayer::Bridge.call(STATE_TOPIC)) || IDLE_STATE
  end

  # Calls a topic of the DLL's parking.
  #
  # @param topic [String] The topic.
  # @param request [Hash, nil] The request.
  # @return [Hash, nil] The answer, nil when the DLL gave none.
  def self.answer(topic, request = nil)
    told = MGQ_Multiplayer::Bridge.call(topic, request)
    unless told.is_a?(Hash)
      log_once(topic, "#{topic} gave no answer")
      return nil
    end

    MGQ_MpWorldMods.forget_installed if told["moved"]
    told
  end

  # Keeps the state an answer carries.
  #
  # @param told [Hash, nil] The answer.
  # @return [Hash, nil] The answer.
  def self.take(told)
    @state = told if told && told.key?("holding")
    told
  end
end

# What this script takes part in of the world, through overworld_sync.rbx.

begin
  MGQ_MpOverworldSync.route(MGQ_MpOverworldSync::MODS_RULE_FIELD) { |_peer, message| MGQ_MpModParking.pushed(message) } if defined?(MGQ_MpOverworldSync::MODS_RULE_FIELD)
rescue => e
  MGQ_MpModParking.log("overworld sync FAILED: #{e.class}: #{e.message}")
end

# Game hooks shared with other scripts, through core_hooks.rbx.

begin
  # As the title screen first starts, a game that closed while mods were parked puts them back.
  # Before blocks run from the last registered, so this runs before MGQ_MpWorld closes the world.
  MGQ_MpHooks.before(Scene_Title, :start, "world_mods_parking") { MGQ_MpModParking.title_started }

  # The title screen tells why the game starts again, then starts it again.
  MGQ_MpHooks.after(Scene_Title, :update, "world_mods_parking") { MGQ_MpModParking.on_title_update(self) }

  # Before the title screen ends, the box goes off the screen.
  MGQ_MpHooks.before(Scene_Title, :terminate, "world_mods_parking") { MGQ_MpModParking.hide_box }

  # Every scene takes a game whose world now turns other mods off to the title screen.
  MGQ_MpHooks.after(Scene_Base, :update, "world_mods_parking") { MGQ_MpModParking.tick }
rescue => e
  MGQ_MpModParking.log("hooks FAILED: #{e.class}: #{e.message}")
end

begin
  # Outside a world, a game that runs without the player's other mods saves nothing; the save screen
  # plays its buzzer for a save that answers false.
  [:save_game, :auto_save_game].select { |name| DataManager.singleton_class.method_defined?(name) }.each do |name|
    MGQ_MpHooks.around(DataManager.singleton_class, name, "world_mods_parking") do |_manager, _args, original|
      MGQ_MpModParking.save_allowed?(name == :auto_save_game) ? original.call : false
    end
  end
rescue => e
  MGQ_MpModParking.log("save hooks FAILED: #{e.class}: #{e.message}")
end
