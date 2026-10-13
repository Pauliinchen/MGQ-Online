#----------------------------------------------------------------
#  core_log.rbx
#
#  Changelog:
#      Paulinchen  2026-10-10: Made log and log_once return nil
#      Paulinchen  2026-10-07: Added failure
#                            - Added short and named
#      Paulinchen  2026-10-04: Renamed from mp_log.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# Writes the scripts' lines to Multiplayer InGame.log. A script's module extends this and starts
# each of its lines with its LOG_TAG, such as "co-op".
#
# Writing a line never raises, since the log must never interrupt the game.
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

  # Shortens a text for a line of the log, such as a chat line, keeping it on one line.
  #
  # @param text [Object] The text.
  # @param length [Integer] The most characters kept.
  # @return [String] The text, cut with "..." when longer.
  def self.short(text, length = 80)
    text = text.to_s.gsub(/[\r\n]+/, " ")
    text.length > length ? "#{text[0, length - 3]}..." : text
  rescue
    "?"
  end

  # Names an entry of the game's database with its id, such as "517 Puruel", for a line of the log.
  #
  # @param table [Array, nil] The database, such as $data_actors.
  # @param id [Integer, nil] The entry's id.
  # @return [String] The id and the entry's name, the id alone when the database lacks a name.
  def self.named(table, id)
    entry = table && id.is_a?(Integer) && id >= 0 ? table[id] : nil
    name = entry && entry.respond_to?(:name) ? entry.name.to_s : ""
    name.empty? ? id.to_s : "#{id} #{name}"
  rescue
    id.to_s
  end

  # Describes an error for a line of the log, adding the pictures in memory to an RGSSError.
  #
  # The count tells a leak of pictures from a single picture too large to make.
  #
  # @param error [Exception] The error.
  # @return [String] Its class and message, "?" when it cannot be described.
  def self.failure(error)
    text = "#{error.class}: #{error.message}"
    text << " (#{bitmaps_alive} pictures in memory)" if defined?(RGSSError) && error.is_a?(RGSSError)
    text
  rescue
    "?"
  end

  # Counts the pictures the game holds in memory.
  #
  # @return [Integer, String] How many are not disposed, "?" where they cannot be counted.
  def self.bitmaps_alive
    ObjectSpace.each_object(Bitmap).count { |bitmap| !bitmap.disposed? }
  rescue
    "?"
  end

  # Writes a line to Multiplayer InGame.log, after the script's LOG_TAG.
  #
  # Many methods give nothing through `return log(...)`, so a log must never hand back what writing
  # the file returned, such as its byte count.
  #
  # @param message [String] The line.
  # @return [nil] Always.
  def log(message)
    MGQ_Multiplayer::Log.write("#{self::LOG_TAG}: #{message}")
    nil
  rescue
    nil
  end

  # Writes a line the first time only, for what would otherwise fail every frame.
  #
  # @param key [Object] What tells the line from the script's other lines.
  # @param message [String] The line.
  # @return [nil] Always, see log.
  def log_once(key, message)
    log(message) if MGQ_MpLog.first_time?(self, key)
    nil
  end
end
