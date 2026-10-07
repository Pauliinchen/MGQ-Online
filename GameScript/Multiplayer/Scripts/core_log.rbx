#----------------------------------------------------------------
#  core_log.rbx
#
#  Changelog:
#      Paulinchen  2026-10-07: Added failure, which describes an error with the pictures in memory when one could not be made
#                            - Added short and named, which cut a text and name a database entry with its id for a line of the log
#      Paulinchen  2026-10-04: Renamed from mp_log.rbx
#      Paulinchen  2026-10-03: Created
#
#----------------------------------------------------------------

# The scripts' lines in Multiplayer InGame.log. A script's module extends this and names its lines
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

  # Describes an error for a line of the log, with the pictures in memory after a picture could not
  # be made, which tells a leak of pictures from one too large.
  #
  # @param error [Exception] The error.
  # @return [String] Its class and message.
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
