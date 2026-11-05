#----------------------------------------------------------------
#  screen_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Wrote the screen's texts out instead of reading recorded ones
#      Paulinchen  2026-11-05: Answered the world screen's model with the values each test sets instead of the screen's methods as they were before they moved to C#
#      Paulinchen  2026-11-01: Dropped the details' old methods for tests, which read only the prototype
#      Paulinchen  2026-10-31: Stopped calling the deleted mp_dir_refresh as the screen opens
#      Paulinchen  2026-10-30: Turned off none of the player's mods, without the parking
#      Paulinchen  2026-10-23: Fetched the list as the DLL's screen does when it opens
#                            - Created
#
#----------------------------------------------------------------

# Answers the topics of the world screen's model (ScreenTopics: screen.*) on a FakeBridge with the
# fixed values each test sets for its case: the list's rows, and a row's details, choices and list
# box lines by its key. The screen's texts are the ones the DLL answers (TEXTS). Unless a test sets
# them, the list stands idle without rows and a row has no details, no choice but Back and no
# lines. Every rule (the rows' order and colours, the panels, which choices a world offers) is
# WorldScreenModelTests' and ScreenTopicsTests' to cover.

require "json"
require_relative "bridge_support"

# Stands in for the DLL's answers of the world screen's model.
class ScreenAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(screen.open screen.close screen.texts screen.list screen.world screen.details screen.actions screen.box).freeze

  # The screen's texts as the DLL answers them.
  TEXTS = {
    "hint" => "Up and down pick the worlds or the commands, confirm moves into them. Right arrow on a world: its details.",
    "enter_hint" => "Confirm to enter it.",
    "busy" => {
      "create" => "Creating the world . . .", "unlock" => "Opening the world . . .", "delete" => "Deleting the world . . .", "ban" => "Removing the player . . .",
      "edit" => "Saving the changes . . .", "find" => "Looking for the world . . .", "data" => "Updating the game data . . .",
      "start" => "Fetching the starting save . . .", "mods" => "Downloading the mods . . .", "settings" => "Saving the mod settings . . .",
      "read" => "Reading the world's mods . . .",
    },
  }.freeze

  # The list while the DLL fetched none.
  IDLE = { "state" => "idle", "error" => nil, "admin" => false, "info" => nil, "rows" => [] }.freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # @return [Hash] What screen.list answers.
  attr_accessor :list

  # @return [Hash] What screen.details answers, by the row's key.
  attr_reader :details

  # @return [Hash] What screen.actions answers, by the row's key: each choice's label, symbol and
  #   whether it can be chosen.
  attr_reader :actions

  # @return [Hash] What screen.box answers, by the row's key and the kind, such as ["w1", "players"].
  attr_reader :boxes

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @list = IDLE
    @details = {}
    @actions = {}
    @boxes = {}
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Forgets the requests taken so far, so a check reads only those of its own case.
  def clear
    @asked.clear
  end

  # Answers a topic with what the test set.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    case topic
    when "screen.texts" then TEXTS
    when "screen.list" then @list
    when "screen.world" then world(request)
    when "screen.details" then @details[request]
    when "screen.actions" then @actions[request]
    when "screen.box" then @boxes[[request["key"], request["kind"]]]
    end
  end

  private

  # Finds a world of the list as screen.world answers it.
  #
  # @param id [String] The world's id.
  # @return [Hash] How the list stands and the world, nil when no row holds it.
  def world(id)
    row = @list["rows"].find { |each| each["id"] == id }
    { "state" => @list["state"], "listed" => row && row["listed"] }
  end
end

# Answers the world screen's model with the values each test sets, kept in $screens; a bridge
# answered already keeps its answers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [ScreenAnswers] The answers.
def answer_screen(fake)
  $screens = ScreenAnswers.new(fake) unless $screens && $screens.fake.equal?(fake)
  $screens
end

# Makes a row of the list as screen.list tells it, its key its directory id or its folder's.
#
# @param name [String] The world's name.
# @param fields [Hash] What differs: such as "id", "listed" (see listed_value), "local" (as
#   worlds.local tells a world), "text", "count", "color" ("raid", "featured", "favourite" or
#   "normal"), "dim", "favourite" and "gone".
# @return [Hash] The row.
def screen_row(name, fields = {})
  id = fields.key?("id") ? fields["id"] : fields["listed"] && fields["listed"]["id"]
  key = id || "folder:#{fields['local']['id']}"
  { "key" => key, "id" => id, "name" => name, "text" => name, "count" => "", "color" => "normal", "dim" => false, "favourite" => false, "gone" => false,
    "listed" => nil, "local" => nil }.merge(fields)
end

# Makes the row of a world of the directory.
#
# @param listed [Hash] The world, see listed_value.
# @param fields [Hash] What else differs, see screen_row.
# @return [Hash] The row.
def listed_row(listed, fields = {})
  screen_row(listed["name"], { "listed" => listed }.merge(fields))
end

# Sets the list screen.list answers and tells the screen it changed.
#
# @param rows [Array<Hash>] The rows, see screen_row.
# @param state [String] How the list stands: "idle", "loading", "ready" or "failed".
# @param fields [Hash] What else differs: "error", "admin" or "info".
def screen_list(rows, state = "ready", fields = {})
  $screens.list = { "state" => state, "error" => nil, "admin" => false, "info" => nil, "rows" => rows }.merge(fields)
  screen_changed
end

# Makes the entry the screen makes of a row.
#
# @param row [Hash] The row, see screen_row.
# @return [MGQ_MpWorld::Entry] The entry.
def screen_entry(row)
  MGQ_MpWorldScreen.entry_of(row)
end

# Makes a world's details as screen.details tells them: its World panel naming its creator, its
# mods as chips that open the list box, its players that open it too, and its description.
#
# @param title [String] The world's name.
# @param mods [Array<String>] Its mods.
# @param players [Array<String>] Its players.
# @param description [String, nil] Its description, nil for none.
# @return [Hash] The details.
def screen_details(title, mods, players, description)
  cell = lambda { |label, text, extra = {}| { "label" => label, "text" => text, "color" => "normal", "target" => nil, "chips" => nil, "chip_colors" => nil }.merge(extra) }
  { "title" => title, "title_color" => nil, "played" => "", "description" => description,
    "panels" => [{ "title" => "World", "note" => nil, "target" => nil, "rows" => [[cell.call("Creator", "Cara")]] },
                 { "title" => "Game data", "note" => nil, "target" => nil, "rows" => [[cell.call("Mods", mods.join(", "), "target" => "mods", "chips" => mods)]] },
                 { "title" => "Players", "note" => "#{players.size} joined", "target" => "players", "rows" => [players.map { |name| cell.call(nil, name) }] }] }
end

# Tells the screen that the list and what the details read changed, as the DLL's drain does.
def screen_changed
  MGQ_MpWorld::Changes.note(MGQ_MpWorld::Changes::LIST | MGQ_MpWorld::Changes::DETAILS)
end
