#----------------------------------------------------------------
#  story_index.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Derives the story mapping's index for the relay (see Relay/README.md, Story mapping): which map
# events and common events share their self switches because they read or write a key the mapping
# shares, and the names of the story's keys, over the game folder the server runs in. The relay
# asks over its own connection, {"op":"story_index","rowsRev":N,"keys":[...],"events":[...]},
# whenever the mapping's rows changed; MGQ Online's C# core does the work (its topic story.index),
# so a server without the core answers that it cannot.
module StoryIndex
  # The core's topic.
  TOPIC = "story.index"

  # The fields of each table's rows the index reads.
  FIELDS = { "keys" => %w[key kind], "events" => %w[key share] }

  class << self
    # Answers the relay's request.
    #
    # @param request [Hash] The request: rowsRev, the revision of the rows, and the rows of keys and events.
    # @return [Hash] ok, built (the rows' revision), events (each [map, event]), commons and names;
    #   or ok false and why.
    def answer(request)
      built = request["rowsRev"]
      return { ok: false, error: "rowsRev must be the rows' revision" } unless built.is_a?(Integer) && built >= 0
      return { ok: false, error: "this battle server runs without MGQ Online's C# core, which derives the index" } unless core?

      rows = FIELDS.to_h { |table, fields| [table, rows_of(request[table], fields)] }
      found = MGQ_Multiplayer::Bridge.call!(TOPIC, rows)
      { ok: true, built: built, events: found["events"], commons: found["commons"], names: found["names"] }
    rescue MGQ_Multiplayer::Bridge::Error => e
      { ok: false, error: e.message }
    end

    private

    # Tells whether the core answers the topic.
    #
    # @return [Boolean] Whether it does.
    def core?
      defined?(MGQ_Multiplayer::Bridge) && MGQ_Multiplayer::Bridge.has?(TOPIC) ? true : false
    end

    # Takes the fields of each row the index reads, texts only.
    #
    # @param rows [Object] The rows as the relay sent them.
    # @param fields [Array<String>] The fields.
    # @return [Array<Hash>] The rows.
    def rows_of(rows, fields)
      Array(rows).select { |row| row.is_a?(Hash) }.map { |row| fields.to_h { |field| [field, row[field].to_s] } }
    end
  end
end
