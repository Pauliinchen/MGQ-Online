#----------------------------------------------------------------
#  world_mods_parking.rbx
#
#  Changelog:
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
# Patch.rb reads the folder's file list once as the game starts, so a moved file takes effect only
# with the next start.
module MGQ_MpModParking
  extend MGQ_MpLog

  # What starts this script's lines in Multiplayer InGame.log.
  LOG_TAG = "mod parking"

  # Bytes the DLL may write the parked files into at first. More asks for a larger buffer.
  PARKED_SIZE = 4096

  # Bytes the DLL may write the scripts it could park into at first. More asks for a larger buffer.
  SCRIPTS_SIZE = 8192

  # The kinds of lines mp_mods_scripts writes for the scripts the DLL can park: a script in the Patch
  # folder, and a parked one.
  SCRIPT_KINDS = %w[patch parked]

  # The kind of line mp_mods_scripts writes for a script behind a link to another drive, which the
  # DLL cannot park.
  ELSEWHERE_KIND = "elsewhere"

  # The line mp_mods_scripts writes when it could not list the scripts.
  SCRIPTS_FAILED = "error"

  # What starts the answer of mp_mods_parked when the DLL could not read its journal, the message
  # following a tab.
  PARKED_FAILED = /\Aerror[\t=]/

  # The folder the scripts are moved out of, relative to the game's folder.
  PATCH_DIR = "Patch"

  # This mod's own folder in the Patch folder, whose scripts the DLL never parks.
  OWN_DIR = "patch/multiplayer/"

  # What mp_mods_restore and mp_mods_recover answer while another game of this folder holds the
  # parked mods, which come back as it closes.
  HELD_ELSEWHERE = -2

  # Frames the open world waits for the list it asked for to check its mods, ten seconds.
  RECHECK_FRAMES = 600

  # Frames between two looks at whether that list arrived, a quarter of a second.
  RECHECK_STEP = 15

  # The setting in Player.ini that tells the start after the last restart to turn the mods back on,
  # so a restore that keeps failing never restarts the game over and over.
  RESTARTED_SETTING = "mods_back_restart"

  # What mp_mods_restart_parked starts the game again for: entering the world. Going back to the
  # title screen puts the mods back in the game and starts it again through mp_restart_game.
  REJOIN = 1

  # Frames the title screen tells why the game starts again before it does, three seconds.
  RESTART_FRAMES = 180

  # Frames a player in a world that now turns other mods off is told so before the game goes to the
  # title screen, once the map is free, five seconds.
  KICK_FRAMES = 300

  # The key of this script's lines in the notification box.
  NOTICE_KEY = :mod_parking

  # Most mods a question names before it counts the rest.
  NAMED_MODS = 3

  # What the world screen asks before parking mods, the world and the mods filled in.
  CONFIRM_TEXT = "These mods are turned off while you play in %s: %s. Restart and join?"

  # What the world screen asks before putting back parked mods that a world allows, the world filled
  # in.
  RETURN_TEXT = "%s allows your turned-off mods, which come back after a restart. Restart and join?"

  # What the world screen adds to the offer to download a world's mods when it parks mods too, the
  # mods filled in.
  ALSO_TEXT = " These mods are turned off while you play there: %s."

  # What the world screen says when mods were moved since the game started, the world filled in.
  RESTART_FIRST_TEXT = "Your mods were turned off or on since the game started. Restart it first, then enter %s."

  # What the world screen asks the creator of a world whose data scan was made with the mods it
  # turns off still on, the world filled in.
  OWN_DATA_TEXT = "The data scan of %s was made with your other mods on. Take your game's data as it is now and enter?"

  # What the world screen says while the catalog, which tells the personal mods, is unknown.
  CATALOG_TEXT = "The mod catalog has not loaded yet. Try again in a moment."

  # What the world screen says when the DLL could not list the scripts, the world filled in.
  SCRIPTS_TEXT = "Your Patch folder could not be read, so you cannot enter %s now. See the log."

  # What the game says when another game of this folder keeps the mods turned off.
  HELD_TEXT = "Another game of this folder has mods turned off. They come back when it closes."

  # What the world screen says when the mods could not be moved, the world filled in.
  PARK_FAILED_TEXT = "Your other mods could not be turned off, so you cannot enter %s now. See the log."

  # What the world screen says under Wine or Proton, the world filled in.
  BY_HAND_TEXT = "Your other mods are turned off. Restart the game by hand: it enters %s once it is back."

  # What the world screen says under Wine or Proton once the parked mods came back, the world filled
  # in.
  BACK_BY_HAND_TEXT = "Your mods are back on. Restart the game by hand: it enters %s once it is back."

  # What the world screen says when the game could not start again, the world filled in.
  RESTART_FAILED_TEXT = "The game could not start again, so your mods stay on and %s was not entered."

  # What the world screen says when a world's downloaded mods were installed, but the other mods
  # could not be turned off or kept off for the restart, the world filled in.
  NOT_KEPT_TEXT = "The mods were installed, but your other mods could not be turned off or kept off for %s. Try again."

  # What the world screen says when a world's downloaded mods were installed, but the parked mods
  # the world allows could not be turned back on for the restart, the world filled in.
  NOT_BACK_ON_TEXT = "The mods were installed, but your other mods could not be turned back on for %s. Try again."

  # What the world screen says when scripts the world turns off lie behind a link to another drive,
  # their count and the first one's path filled in.
  ELSEWHERE_TEXT = "%d mod scripts lie on another drive behind a link in Patch and cannot be turned off: %s."

  # What the world screen says when one script the world turns off lies behind a link to another
  # drive, the count and its path filled in.
  ELSEWHERE_ONE_TEXT = "%d mod script lies on another drive behind a link in Patch and cannot be turned off: %s."

  # What the title screen adds when a restore sent mods to the conflicts folder, their count filled
  # in.
  CONFLICTS_TEXT = "%d of your mods went to Parked mods/Conflicts because another file took their place in Patch."

  # What the game says when the player saves while the session runs without their other mods.
  SAVE_OFF_TEXT = "Saving is off until your other mods are back. Start the game again to bring them back."

  # What the box on the title screen is called while the mods come back.
  BACK_TITLE = "Turning your mods back on"

  # What the box on the title screen says as the player left a world that turned other mods off.
  LEAVE_TEXT = "Your mods are back after a restart."

  # What the box says at the first start after the game closed while mods were parked.
  RECOVERED_TEXT = "The game closed while mods were turned off. Your mods are back after a restart."

  # What the box says when a restore failed.
  NOT_BACK_TEXT = "Some of your mods could not be turned back on. They wait in the game folder's Parked mods, and the game tries again at its next start."

  # What the box says when the game cannot start again by itself.
  RESTART_BY_HAND_TEXT = "Your mods are back once you start the game again. Close it and start it again."

  # What a player in a world that now turns other mods off is told, the world filled in.
  NOW_OFF_TEXT = "%s now turns off other mods. Enter it again to play."

  # The hint of the box while the game is about to start again.
  RESTART_HINT = "The game starts again in a moment."

  # The hint of the box while it only tells something.
  NOTICE_HINT = "Enter, Esc or Numpad 0: close"

  # Title screens this session started.
  @title_starts = 0

  # Deciding which mods to park.

  # Tells whether this game is one the World Admin tool started for the Mod Config options, which
  # quits at once and must neither park nor restore.
  #
  # @return [Boolean] Whether it is.
  def self.dump?
    MGQ_MpWorldMods.dump_requested?
  end

  # Tells whether the DLL can park and restore.
  #
  # @return [Boolean] Whether the mod's DLL is installed and this is no options dump.
  def self.usable?
    MGQ_Multiplayer.available? && !dump?
  end

  # Reads what the DLL has parked.
  #
  # An unreadable journal does not mean that nothing is parked, so the state read last stands in
  # for it.
  #
  # @return [Hash] "world", "files" and "conflicts" (of the last restore), and :paths, the parked
  #   files relative to the game's folder; empty when nothing is parked or the DLL cannot tell.
  def self.parked_state
    return {} unless usable?

    text = MGQ_Multiplayer::Link.read('mp_mods_parked', PARKED_SIZE)
    if text =~ PARKED_FAILED
      log_once(:parked_failed, "the DLL could not read the parked mods (#{text.split("\n").first.to_s.sub(PARKED_FAILED, '')}), keeping the state read last")
      return @last_state || {}
    end

    state = text.empty? ? {} : MGQ_Multiplayer::Link.parse(text)
    state[:paths] = state[:payload].to_s.split("\n").map { |line| line.strip }.reject { |line| line.empty? } unless text.empty?
    @last_state = state
  rescue => e
    log_once(:parked, "reading the parked mods failed: #{e.class}: #{e.message}")
    {}
  end

  # Lists the parked files.
  #
  # @return [Array<String>] Their paths relative to the game's folder, such as "Patch/Invasions.rb".
  def self.parked_paths
    parked_state[:paths] || []
  end

  # Tells whether any mod is parked.
  #
  # @return [Boolean] Whether one is.
  def self.parked?
    !parked_paths.empty?
  end

  # Lists the scripts of the Patch folder that no world turns off: the mod loader, this mod and Mod
  # Config Remake, by their file's name in any folder, as Patch.rb skips its own, and every script
  # in this mod's own folder, as the DLL's parking does.
  #
  # @param path [String] A script's path.
  # @return [Boolean] Whether it is one of them.
  def self.shared?(path)
    path_key(path).start_with?(OWN_DIR) || MGQ_MpWorld::SHARED_SCRIPTS.include?(MGQ_MpWorld.mod_key(File.basename(path)))
  end

  # Lists the scripts this game would have with every mod on: the Patch folder's and the parked ones,
  # as the DLL lists them, which leaves out those shared? names.
  #
  # The DLL lists them because the game's Ruby hands out file names in the ANSI code page, which
  # loses every character it cannot hold.
  #
  # @return [Array<String>, nil] Their paths relative to the game's folder in UTF-8, each once; nil
  #   when the DLL could not list them.
  def self.scripts
    scripts_of(SCRIPT_KINDS)
  end

  # Lists the scripts behind a link to another drive, which the DLL cannot park, see scripts.
  #
  # @return [Array<String>, nil] Their paths relative to the game's folder, each once; nil when the
  #   DLL could not list them.
  def self.elsewhere
    scripts_of([ELSEWHERE_KIND])
  end

  # Lists the scripts of some kinds of lines mp_mods_scripts writes, leaving out those shared? names.
  #
  # @param kinds [Array<String>] The kinds, see SCRIPT_KINDS and ELSEWHERE_KIND.
  # @return [Array<String>, nil] Their paths relative to the game's folder in UTF-8, each once; nil
  #   when the DLL could not list them.
  def self.scripts_of(kinds)
    return nil unless usable?

    text = MGQ_Multiplayer::Link.read('mp_mods_scripts', SCRIPTS_SIZE).dup.force_encoding("UTF-8")
    lines = text.split("\n").map(&:chomp)
    if lines.include?(SCRIPTS_FAILED)
      log_once(:scripts, "the DLL could not list the scripts of the Patch folder")
      return nil
    end

    found = lines.map { |line| line.split("\t", 2) }
    found = found.select { |kind, path| kinds.include?(kind) && path && !path.empty? }.map { |_kind, path| path }
    found.reject { |path| shared?(path) }.uniq { |path| path_key(path) }
  rescue => e
    log_once(:scripts, "listing the scripts failed: #{e.class}: #{e.message}")
    nil
  end

  # Turns a path into what two paths are compared by.
  #
  # @param path [String] The path.
  # @return [String] It with forward slashes, in lower case.
  def self.path_key(path)
    path.to_s.tr("\\", "/").downcase
  end

  # Names the mod a script belongs to: the folder it sits in right under the Patch folder, or for a
  # script right in the Patch folder its own file's name.
  #
  # Patch.rb loads the scripts of every folder under the Patch folder too, and a mod keeps its
  # helper scripts in a folder named after it.
  #
  # @param path [String] The script's path relative to the game's folder, such as
  #   "Patch/Luka_Replacer/heroes.rb".
  # @return [String] The mod's name as the folder or file has it, such as "Luka_Replacer".
  def self.owner_name(path)
    parts = path.to_s.tr("\\", "/").split("/").reject { |part| part.empty? }
    parts.shift if parts.size > 1 && parts.first.downcase == PATCH_DIR.downcase
    parts.size > 1 ? parts.first : parts.last.to_s.sub(/\.rb\z/i, "")
  end

  # Tells which mod a script belongs to, see owner_name.
  #
  # @param path [String] The script's path relative to the game's folder.
  # @return [String] The mod's key, see MGQ_MpWorld.mod_key.
  def self.owner_key(path)
    MGQ_MpWorld.mod_key(owner_name(path))
  end

  # Lists the scripts a world's mods would turn off: every script but those of the mods the world
  # names, of the personal ones and those every player has.
  #
  # @param mods [String, nil] The world's mods as its creator wrote them.
  # @return [Array<String>, nil] The scripts' paths, sorted; nil while the DLL cannot list them, or
  #   while the catalog, which tells the personal mods, is unknown and a script might be one.
  def self.to_turn_off(mods)
    turned_off(scripts, mods)
  end

  # Picks the scripts a world's mods would turn off from some scripts, see to_turn_off.
  #
  # @param found [Array<String>, nil] The scripts' paths; nil while the DLL cannot list them.
  # @param mods [String, nil] The world's mods as its creator wrote them.
  # @return [Array<String>, nil] The paths it turns off, sorted; nil while they are unknown.
  def self.turned_off(found, mods)
    return nil if found.nil?

    named = MGQ_MpWorld.mods_of(mods).map { |name| MGQ_MpWorld.mod_key(name) }
    others = found.reject { |path| named.include?(owner_key(path)) }
    return [] if others.empty?

    personal = MGQ_MpWorldMods.personal_keys
    return nil if personal.nil?

    others.reject { |path| personal.include?(owner_key(path)) }.sort_by { |path| path_key(path) }
  end

  # Lists the scripts a world turns off.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Array<String>, nil] The scripts' paths, none for a world that allows other mods; nil
  #   while they are unknown, see to_turn_off.
  def self.plan_for(listed)
    listed.other_mods_off ? to_turn_off(listed.mods) : []
  end

  # Lists the scripts behind a link to another drive that a world turns off, which keep the game
  # out of it, since the DLL cannot park them.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Array<String>, nil] The scripts' paths, none for a world that allows other mods; nil
  #   while they are unknown, see to_turn_off.
  def self.stuck_for(listed)
    listed.other_mods_off ? turned_off(elsewhere, listed.mods) : []
  end

  # Tells why scripts behind a link to another drive keep the game out of a world.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [String] How many there are and the first one's path.
  def self.elsewhere_text(listed)
    stuck = stuck_for(listed) || []
    format(stuck.size == 1 ? ELSEWHERE_ONE_TEXT : ELSEWHERE_TEXT, stuck.size, stuck.first.to_s)
  end

  # Tells what has to change before the game may enter a world: the scripts to park, which the DLL
  # sets as the parked ones, putting back those parked that the world allows.
  #
  # While the catalog is unknown, the mods parked for the world stay as they are, since they were
  # parked with a known one.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Array<String>, Symbol, nil] The scripts to have parked, none to put every parked one
  #   back; :restart when this session moved scripts, which load only at the next start; :unlisted
  #   when the DLL could not list the scripts; :elsewhere when scripts it turns off lie behind a
  #   link to another drive; :unknown while the catalog is unknown; nil when the parked ones are
  #   those already.
  def self.change_for(listed)
    return :restart if moved_here?
    return :unlisted if listed.other_mods_off && scripts.nil?
    return :elsewhere unless (stuck_for(listed) || []).empty?

    plan = plan_for(listed)
    state = parked_state
    parked = state[:paths] || []
    if plan.nil?
      return :unknown if parked.empty? || state["world"] != listed.id

      log_once(:catalog_unknown, "the catalog is unknown, so the mods parked for world #{MGQ_MpWorld.short(listed.id)} stay as they are")
      return nil
    end

    keys_of(plan) == keys_of(parked) ? nil : plan
  end

  # Turns paths into what a set of them is compared by.
  #
  # @param paths [Array<String>] The paths.
  # @return [Array<String>] Their keys, sorted.
  def self.keys_of(paths)
    paths.map { |path| path_key(path) }.sort
  end

  # Has the DLL's journal name the world the game is about to enter, or start again into, when the
  # mods parked for another world are exactly those this one turns off.
  #
  # The start after a restart keeps the mods parked only for the world the journal names, and puts
  # them back for any other.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Boolean] Whether the journal names the world now; false when it names another or none.
  def self.claim(listed)
    state = parked_state
    parked = state[:paths] || []
    return false if parked.empty?
    return true if state["world"] == listed.id

    plan = plan_for(listed)
    return false unless plan && keys_of(plan) == keys_of(parked)

    log("the mods parked for world #{MGQ_MpWorld.short(state['world'])} are those world #{MGQ_MpWorld.short(listed.id)} turns off, parking them for it")
    park(plan, listed.id) && parked_state["world"] == listed.id
  rescue => e
    log("parking the mods for another world failed: #{e.class}: #{e.message}")
    false
  end

  # Notes which scripts were parked as this session started, before it moves any.
  def self.note_start
    @start_parked ||= keys_of(parked_paths)
  end

  # Tells whether this session moved scripts in or out of the Patch folder, which load only at the
  # next start, so the scripts it runs are not those the folder holds.
  #
  # @return [Boolean] Whether it did.
  def self.moved_here?
    !@start_parked.nil? && keys_of(parked_paths) != @start_parked
  end

  # Tells whether this session runs with a world's other mods turned off, as the start after the
  # parking restart does.
  #
  # @param listed [MGQ_MpWorld::Directory::ListedWorld] The world.
  # @return [Boolean] Whether it does.
  def self.parked_for?(listed)
    state = parked_state
    listed.other_mods_off && !(state[:paths] || []).empty? && state["world"] == listed.id && !moved_here?
  end

  # Names scripts as the player knows them.
  #
  # @param paths [Array<String>] The scripts' paths.
  # @return [Array<String>] Their file names without ".rb".
  def self.names_of(paths)
    paths.map { |path| File.basename(path.to_s, ".rb") }
  end

  # Groups scripts by the mod they belong to, see owner_name.
  #
  # @param paths [Array<String>] The scripts' paths.
  # @return [Array<Array>] Each mod's name and how many of the scripts are its, in the order of
  #   their first script.
  def self.mods_of(paths)
    mods = {}
    paths.each do |path|
      mod = (mods[owner_key(path)] ||= [owner_name(path), 0])
      mod[1] += 1
    end
    mods.values
  end

  # Names a few of the mods scripts belong to and counts the rest.
  #
  # @param paths [Array<String>] The scripts' paths.
  # @return [String] Such as "Invasions, Level_Cap and 2 more".
  def self.list_text(paths)
    MGQ_MpWorldMods.list_text(mods_of(paths).map { |name, _count| name }, NAMED_MODS)
  end

  # Asks whether to park mods and enter a world, or to put the parked ones back for it.
  #
  # @param world [String] The world's name.
  # @param plan [Array<String>] The scripts to park, none to put every parked one back.
  # @return [String] The question.
  def self.confirm_text(world, plan)
    plan.empty? ? format(RETURN_TEXT, world) : format(CONFIRM_TEXT, world, list_text(plan))
  end

  # Tells what the offer to download a world's mods parks too.
  #
  # @param plan [Array<String>, Symbol, nil] What change_for tells.
  # @return [String] The sentence with a space in front, "" when nothing more is parked.
  def self.also_text(plan)
    plan.is_a?(Array) && !plan.empty? ? format(ALSO_TEXT, list_text(plan)) : ""
  end

  # Moving the files.

  # Has the DLL park scripts, putting back those parked before that are not among them.
  #
  # @param plan [Array<String>] The scripts' paths relative to the game's folder.
  # @param world_id [String] The world they are parked for.
  # @return [Boolean] Whether exactly these scripts are parked now.
  def self.park(plan, world_id)
    return false unless usable?

    note_start
    @owned = true
    answer = MGQ_Multiplayer::Link.function('mp_mods_park').call(plan.join("\n") + "\0", world_id.to_s + "\0")
    parked = parked_paths.map { |path| path_key(path) }.sort
    done = parked == plan.map { |path| path_key(path) }.sort
    MGQ_MpWorldMods.forget_installed
    log(done ? "parked #{plan.size} script(s) for world #{MGQ_MpWorld.short(world_id)} (DLL answered #{answer}): #{names_of(plan).join(', ')}" :
               "parking #{names_of(plan).join(', ')} for world #{MGQ_MpWorld.short(world_id)} failed (DLL answered #{answer}), parked now: #{parked.join(', ')}")
    done
  rescue => e
    log("parking the mods failed: #{e.class}: #{e.message}")
    false
  end

  # Has the DLL put every parked script back.
  #
  # @param after_title [Boolean] Whether the game starts again on the title screen afterwards, for
  #   the DLL's log.
  # @return [Integer] How many came back, -1 when one could not, HELD_ELSEWHERE while another game
  #   of this folder holds them.
  def self.restore(after_title = false)
    return 0 unless usable?

    note_start
    count = MGQ_Multiplayer::Link.function('mp_mods_restore').call(after_title ? 1 : 0)
    MGQ_MpWorldMods.forget_installed
    if count == HELD_ELSEWHERE
      log("another game of this folder holds the parked mods, they stay parked until it closes")
    else
      log(count < 0 ? "putting the parked mods back failed for some, they stay parked" : "put #{count} parked script(s) back")
    end
    count
  rescue => e
    log("putting the parked mods back failed: #{e.class}: #{e.message}")
    -1
  end

  # Starts the game again with the mods parked, to enter the world: the DLL's watchdog waits for
  # this game to close, starts it again and puts the mods back once it closed for good, a crash
  # included.
  #
  # @param world_id [String] The world the mods are parked for.
  # @return [Symbol] :restarting when the game closes now, :by_hand under Wine or Proton, where the
  #   player starts it again, :failed when it could not and stays open.
  def self.restart(world_id)
    answer = MGQ_Multiplayer::Link.function('mp_mods_restart_parked').call(world_id.to_s + "\0", REJOIN)
    case answer
    when 1
      log("starting the game again with the mods parked, to enter world #{MGQ_MpWorld.short(world_id)}")
      :restarting
    when 2
      log("the game cannot start itself again under Wine, so the player does with the mods parked")
      :by_hand
    else
      log("the game could not start itself again with the mods parked")
      :failed
    end
  rescue => e
    log("starting the game again with the mods parked failed: #{e.class}: #{e.message}")
    :failed
  end

  # Parks a world's scripts and starts the game again to enter it, which Player.ini's rejoin tells
  # the next start; puts them back when the game cannot start again.
  #
  # @param plan [Array<String>] The scripts to park, none to put every parked one back.
  # @param world_id [String] The world.
  # @return [Symbol] :restarting, :by_hand, :failed (the game could not start again, the mods are
  #   back), :not_parked (the scripts could not be moved; those moved came back) or :held (another
  #   game of this folder holds the parked ones).
  def self.park_and_rejoin(plan, world_id)
    if plan.empty?
      count = restore
      return :held if count == HELD_ELSEWHERE
      return :not_parked if count < 0

      return MGQ_MpWorldMods.restart(world_id)
    end
    unless park(plan, world_id)
      # A park that moved only some would leave a journal that every later start acts on.
      restore if parked?
      return :not_parked
    end

    result = rejoin_parked(world_id)
    return result unless result == :failed

    restore
    :failed
  end

  # Starts the game again to enter a world with the mods parked for it, which Player.ini's rejoin
  # tells the next start.
  #
  # A plain restart would leave the journal to the watchdog that started this game, which puts the
  # mods back as this game closes, while the next one starts.
  #
  # @param world_id [String] The world the journal names.
  # @return [Symbol] :restarting, :by_hand, or :failed when the game could not start again and
  #   stays open, the mods still parked.
  def self.rejoin_parked(world_id)
    MGQ_Multiplayer::Player.store(MGQ_MpWorldMods::REJOIN_SETTING, world_id)
    result = restart(world_id)
    if result == :by_hand
      # The mods stay parked for the start the player makes, which enters the world.
      @by_hand = true
      @hold = nil
    end
    MGQ_Multiplayer::Player.store(MGQ_MpWorldMods::REJOIN_SETTING, "") if result == :failed
    result
  end

  # Puts the parked mods back once the updater started, which waits for this game to close and then
  # starts it again itself.
  def self.restore_for_update
    restore if parked?
  rescue => e
    log("putting the mods back before the update failed: #{e.class}: #{e.message}")
  end

  # The start after a restart, and the way back to the title screen.

  # Puts back what a game that closed while mods were parked left parked, once a session as the
  # title screen first starts: mods parked for the world this start enters again stay parked.
  #
  # The scripts of this session were read as the game started, so mods put back load only after
  # one more start, which the title screen then makes, once.
  def self.startup
    return if @started

    @started = true
    return unless usable?

    note_start
    rejoin = MGQ_Multiplayer::Player.setting(MGQ_MpWorldMods::REJOIN_SETTING).to_s
    answer = MGQ_Multiplayer::Link.function('mp_mods_recover').call(rejoin + "\0")
    restarted = MGQ_Multiplayer::Player.setting(RESTARTED_SETTING).to_s == "1"
    MGQ_Multiplayer::Player.store(RESTARTED_SETTING, "") if restarted
    @kept_at_start = [2, -1, HELD_ELSEWHERE].include?(answer)
    @owned = [2, -1].include?(answer)

    case answer
    when 2
      @hold = rejoin
      log("the mods stay parked for world #{MGQ_MpWorld.short(rejoin)}, which this start enters again")
    when HELD_ELSEWHERE
      log("another game of this folder holds the parked mods, leaving them to it")
    when 1
      if restarted
        log("put mods back that were parked again after the last restart for them, not restarting again")
        show_notice(with_conflicts(RESTART_BY_HAND_TEXT))
      else
        log("put back the mods a game that closed left parked, restarting so they load")
        restart_to_title(with_conflicts(RECOVERED_TEXT))
      end
    when -1
      log("putting back the mods a game that closed left parked failed")
      show_notice(with_conflicts(NOT_BACK_TEXT))
    end
  rescue => e
    log("looking for parked mods at the start failed: #{e.class}: #{e.message}")
  end

  # Tells whether the game started again to enter a world with its mods parked, and has not
  # entered it yet.
  #
  # @return [Boolean] Whether it has.
  def self.holding?
    !@hold.nil?
  end

  # Notes that a world was entered, which ends the hold of the start that entered it again, and has
  # the world checked against a list fetched now.
  #
  # The list the world was entered from may be older than a change the relay told the world's room
  # before this game joined it.
  def self.entered
    log("entered the world the mods were parked for") if @hold
    @hold = nil
    world = MGQ_MpWorld.world
    recheck(world && world.directory_id)
  end

  # Puts the parked mods back once the start that entered a world again ended without entering it,
  # and starts the game again on the title screen.
  #
  # @param reason [String, nil] Why the world was not entered, for the box on the title screen.
  def self.give_up(reason = nil)
    log("the world #{MGQ_MpWorld.short(@hold)} the mods were parked for was not entered: #{reason || 'no reason given'}")
    @hold = nil
    leave_parked([reason.to_s.strip, LEAVE_TEXT].reject { |part| part.empty? }.join(" "))
  end

  # Counts the title screens of this session, and puts back what a game that closed left parked as
  # the first one starts. Called as the title screen starts, before MGQ_MpWorld closes the world.
  def self.title_started
    startup
    @title_starts += 1
  end

  # Puts the parked mods back as the game returned to the title screen, unless the world stays open
  # there for its new game, this is the first title screen of a start whose recovery kept them
  # parked, or the player restarts the game by hand. Called by MGQ_MpWorld as the title screen
  # starts, after it closed the world.
  #
  # Mods this session neither parked nor kept parked are another game's, which is told only as the
  # player leaves a world, not on every title screen.
  #
  # @param left_world [Boolean] Whether the game left a world for the title screen.
  def self.on_title_start(left_world = false)
    return if @due || @by_hand || !usable?
    return if @kept_at_start && @title_starts <= 1

    @hold = nil
    return unless parked?
    return log("the parked mods are not this session's, leaving them as the title screen starts") unless @owned || left_world

    leave_parked(LEAVE_TEXT)
  rescue => e
    log("putting the mods back on the title screen failed: #{e.class}: #{e.message}")
  end

  # Puts the parked mods back, and has the title screen start the game again so they load, or tells
  # the player when some could not come back, or another game of this folder holds them; a notice
  # waiting for the title screen goes first.
  #
  # @param text [String] What the title screen says.
  def self.leave_parked(text)
    told = @notice
    @notice = nil
    count = restore(true)
    return show_notice([told, HELD_TEXT].compact.join(" ")) if count == HELD_ELSEWHERE

    text = with_conflicts(count >= 0 ? text : NOT_BACK_TEXT)
    count >= 0 ? restart_to_title([told, text].compact.join(" ")) : show_notice([told, text].compact.join(" "))
  end

  # Adds to what the title screen says how many mods the last restore sent to the conflicts folder,
  # since another file took their place in Patch.
  #
  # @param text [String] What the title screen says.
  # @return [String] It, with the sentence on the conflicts after it when there were any.
  def self.with_conflicts(text)
    count = parked_state["conflicts"].to_i
    return text unless count > 0

    log("#{count} parked script(s) went to the conflicts folder, another file having taken their place")
    [text, format(CONFLICTS_TEXT, count)].join(" ")
  end

  # Has the title screen tell why the game starts again, then start it again.
  #
  # @param text [String] What it says.
  def self.restart_to_title(text)
    @due = { :text => text, :frames => RESTART_FRAMES }
    log("the game starts again on the title screen: #{text}")
  end

  # Has the title screen tell the player something.
  #
  # @param text [String] What it says.
  def self.show_notice(text)
    @notice = text
  end

  # Tells whether the title screen is about to start the game again, or tells the player something,
  # which keeps the other scripts from opening the world screen meanwhile.
  #
  # @return [Boolean] Whether it is.
  def self.title_busy?
    !@due.nil? || !@notice.nil?
  end

  # Tells whether the title screen is about to start the game again.
  #
  # @return [Boolean] Whether it is.
  def self.restart_due?
    !@due.nil?
  end

  # Shows the box on the title screen and starts the game again once its time ran out, or closes a
  # notice once the player confirms it. Called by the title screen every frame.
  #
  # @param scene [Scene_Title] The title screen.
  def self.on_title_update(scene)
    startup
    return unless title_busy?

    show_box(scene) unless @box_shown
    return follow_notice if @notice && !@due

    @due[:frames] -= 1
    restart_now if @due[:frames] <= 0
  rescue => e
    log("the title screen's box failed: #{e.class}: #{e.message}")
    hide_box
    @due = nil
    @notice = nil
  end

  # Shows the box and takes the input from the title's commands.
  #
  # @param scene [Scene_Title] The title screen.
  def self.show_box(scene)
    @scene = scene
    @box ||= Sprite_MpMessageBox.new
    @due ? @box.show(BACK_TITLE, @due[:text], RESTART_HINT) : @box.show(BACK_TITLE, @notice, NOTICE_HINT)
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
    log("the player closed the notice: #{@notice}")
    @notice = nil
    hide_box
    commands = @scene && MGQ_MpGame.get(@scene, :command_window)
    commands.activate if commands && !commands.disposed?
  end

  # Starts the game again for the mods put back, or tells the player to, when it cannot.
  def self.restart_now
    @due = nil
    @box_shown = false
    MGQ_Multiplayer::Player.store(RESTARTED_SETTING, "1")
    case MGQ_Multiplayer::Link.function('mp_restart_game').call
    when 1
      log("closing the game to start it again with the mods back")
      SceneManager.exit
    else
      MGQ_Multiplayer::Player.store(RESTARTED_SETTING, "")
      log("the game cannot start itself again, the player starts it again for the mods")
      show_notice(RESTART_BY_HAND_TEXT)
    end
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
  # player's mods, as it started with them parked, or while mods are parked.
  #
  # A save made without a mod loses what the mod keeps in it, and a session goes on without the
  # mods after a restore failed.
  #
  # @return [Boolean] Whether it is.
  def self.saving_off?
    return false if !usable? || MGQ_MpWorld.open?

    !(@start_parked || []).empty? || parked?
  end

  # Refuses a save while saving is off, see saving_off?, and tells the player of a save they made.
  # Called by the game's saves.
  #
  # @param auto [Boolean] Whether it is the autosave, which the player did not ask for.
  # @return [Boolean] Whether the save goes on.
  def self.save_allowed?(auto)
    return true unless saving_off?

    log("refused #{auto ? 'the autosave' : 'a save'}: no world is open and the game runs without the player's other mods")
    MGQ_MpNotices.message(NOTICE_KEY, SAVE_OFF_TEXT) if !auto && defined?(MGQ_MpNotices)
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

    value = message[MGQ_MpOverworldSync::MODS_RULE_FIELD].to_s
    return log("ignored the relay's mods rule #{value.inspect}") unless %w[0 1].include?(value)

    mods = message["mods"].to_s
    MGQ_MpWorldMods.take_mods(mods)
    return unless MGQ_MpWorld.open?

    # The relay's word is newer than any list asked for before it.
    @recheck = nil
    world = MGQ_MpWorld.world
    check_rule(value == "1", mods, "the relay's word", world && world.directory_id)
  rescue => e
    log("taking the relay's mods rule failed: #{e.class}: #{e.message}")
  end

  # Checks the open world's rule against the mods this game runs: a game that runs mods the world
  # turns off goes to the title screen. While the catalog or the scripts are unknown, the game stays
  # and the world is checked again with a list and catalog fetched for it.
  #
  # @param other_mods_off [Boolean] Whether the world turns other mods off.
  # @param mods [String] The world's mods as its creator wrote them.
  # @param source [String] Where the rule comes from, for the log.
  # @param world_id [String, nil] The world's id in the directory, to check it again.
  # @param again [Boolean] Whether this is the check again, which never asks for another.
  def self.check_rule(other_mods_off, mods, source, world_id, again = false)
    return log("#{source}: the world allows other mods, with mods \"#{mods}\"") unless other_mods_off

    plan = to_turn_off(mods)
    # Scripts behind a link to another drive are never parked, so they count as on.
    plan += turned_off(elsewhere, mods) || [] if plan
    if plan.nil?
      log("#{source}: the world turns other mods off, with mods \"#{mods}\", but the catalog or the scripts are unknown: " \
          "#{again ? 'staying in the world' : 'staying in the world until the list and catalog fetched for it arrive'}")
      return again ? nil : recheck(world_id, [other_mods_off, mods])
    end

    parked = parked_paths.map { |path| path_key(path) }
    loaded = plan.reject { |path| parked.include?(path_key(path)) }
    return log("#{source}: the world turns other mods off, with mods \"#{mods}\": none of this game's are on") if loaded.empty?

    log("#{source}: the world turns other mods off, with mods \"#{mods}\": #{names_of(loaded).join(', ')} are on, leaving for the title screen")
    world = MGQ_MpWorld.world
    @kick = { :text => format(NOW_OFF_TEXT, world ? world.name : "The world"), :frames => KICK_FRAMES, :told => false }
  end

  # Has the open world checked again once a list fetched from now arrived, which fetches the
  # catalog too.
  #
  # @param world_id [String, nil] The world's id in the directory; nil checks nothing.
  # @param rule [Array, nil] Whether the world turns other mods off and its mods, as the relay told
  #   them; nil to take both from the list.
  def self.recheck(world_id, rule = nil)
    @recheck = world_id && usable? ? { :id => world_id, :rule => rule, :asked => false, :frames => 0 } : nil
  end

  # Asks for the list once none is being fetched, and checks the open world once it arrived, or
  # gives up on one that never arrives. Called every frame of every scene.
  def self.follow_recheck
    return @recheck = nil unless MGQ_MpWorld.open?

    @recheck[:frames] += 1
    return unless @recheck[:frames] % RECHECK_STEP == 0

    state = MGQ_MpWorld::Directory.list_state
    unless @recheck[:asked]
      return if state == "loading"

      @recheck[:asked] = true
      @recheck[:frames] = 0
      return MGQ_MpWorld::Directory.refresh
    end

    if state == "loading"
      return if @recheck[:frames] < RECHECK_FRAMES

      log("the list asked for to check the world's mods never arrived, staying in the world")
      return @recheck = nil
    end

    check = @recheck
    @recheck = nil
    other_mods_off, mods = check[:rule] || rule_from_list(check[:id])
    check_rule(other_mods_off, mods.to_s, check[:rule] ? "the relay's word, checked again" : "the list after entering", check[:id], true) unless other_mods_off.nil?
  end

  # Reads whether a world turns other mods off, and its mods, from the list.
  #
  # @param world_id [String] The world's id in the directory.
  # @return [Array, nil] Whether it turns other mods off and its mods; nil when the list lacks it.
  def self.rule_from_list(world_id)
    state, _error, worlds = MGQ_MpWorld::Directory.list
    listed = state == "ready" ? worlds.find { |world| world.id == world_id } : nil
    return [listed.other_mods_off, listed.mods.to_s] if listed

    log("the list #{state == 'ready' ? 'lacks the world' : "did not arrive (#{state})"}, so its mods are not checked again")
    nil
  end

  # Tells the player that the world now turns other mods off, and takes the game to the title
  # screen once the time ran out and the player is free on the map. Called every frame of every
  # scene.
  def self.tick
    follow_recheck if @recheck
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

  # Takes the game to the title screen, which closes the world, and tells why there.
  def self.leave_world
    text = @kick[:text]
    @kick = nil
    log("going to the title screen: #{text}")
    show_notice(text)
    scene = SceneManager.scene
    scene.fadeout_all if scene.respond_to?(:fadeout_all)
    SceneManager.goto(Scene_Title)
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
