#----------------------------------------------------------------
#  mp_log.rbx
#
#  Changelog:
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The scripts' lines in the mod's InGame.log. A script's module extends this and names its lines
# with LOG_TAG, which starts each of them, such as "co-op".
#
# It must never interrupt the game, so writing a line never raises.
module MGQ_MpLog
  # What was logged once already, by the module and its key.
  @logged = {}

  # Notes that a module logs a line it logs only once.
  #
  # @param owner [Module] The module.
  # @param key [Object] What tells the line from the module's other lines.
  # @return [Boolean] Whether this is the first time.
  def self.first_time?(owner, key)
    return false if @logged[[owner, key]]

    @logged[[owner, key]] = true
  end

  # Writes a line to the mod's InGame.log, after the script's LOG_TAG.
  #
  # @param message [String] The line.
  def log(message)
    MGQ_Multiplayer::Log.write("#{self::LOG_TAG}: #{message}")
  rescue
  end

  # Writes a line the first time only, for what would otherwise fail every frame.
  #
  # @param key [Object] What tells the line from the script's other lines.
  # @param message [String] The line.
  def log_once(key, message)
    log(message) if MGQ_MpLog.first_time?(self, key)
  end
end
