#----------------------------------------------------------------
#  local_worlds_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the worlds on this PC, the lists, the invite, the game data and the mod picker with the values each test sets instead of a copy of the C# rules
#      Paulinchen  2026-10-23: Dropped the stand-ins of the topics the DLL no longer has
#                            - Handed out each mod's label and colour in the picker and left the entries to the screen's stand-in
#                            - Created
#
#----------------------------------------------------------------

# Answers the topics of the worlds on this PC (LocalWorldTopics), the player's lists of worlds, the
# Discord invite, the game data compared and the mod picker (ModPickTopics) on a FakeBridge with the
# fixed values each test sets for its case. Unless a test sets an answer, the DLL keeps the worlds a
# test put on this PC and writes into them what it is handed, and has nothing else to say: no world
# found, no save, no hidden world added, no invite, no comparison and no picker. Every rule (how
# world.ini reads, which save is the latest, how a world code changes, what differs, what the picker
# does) is the C# tests' to cover.

require_relative "bridge_support"

# Stands in for the DLL's answers of the worlds on this PC and the mod picker.
class LocalWorldAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(worlds.local worlds.found worlds.describe worlds.update worlds.latest_save worlds.added worlds.invite worlds.invite_take
              worlds.game_data worlds.data_differing worlds.data_text modpick.open modpick.act modpick.close).freeze

  # When the DLL writes a world played, in seconds since 1970.
  PLAYED_AT = 1_800_000_000

  # The fields worlds.describe and worlds.update keep when a request names them.
  KEPT_FIELDS = %w(name world type share difficulty squad raid_bosses seats).freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # @return [Hash] The worlds on this PC, by folder id, each as worlds.local tells it.
  attr_reader :worlds

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    @worlds = {}
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Sets what a topic answers: a value, or a block that makes it of the request.
  #
  # @param topic [String] The topic.
  # @param value [Object] The answer, nil to answer as before the test set one.
  # @yieldparam request [Object] The request.
  def set(topic, value = nil, &block)
    block || !value.nil? ? @fixed[topic] = (block || value) : @fixed.delete(topic)
  end

  # Forgets the requests taken so far, so a check reads only those of its own case.
  def clear
    @asked.clear
  end

  # Puts a world on this PC as worlds.local tells it.
  #
  # @param id [String] The folder's id.
  # @param values [Hash] What differs from a plain Classic world without a directory id.
  # @return [Hash] The world.
  def keep(id, values)
    @worlds[id] = { "id" => id, "name" => "World", "code" => "code", "world" => nil, "created" => 0, "played" => nil, "type" => nil, "share" => nil,
                    "difficulty" => nil, "squad" => nil, "raid_bosses" => false, "seats" => 0 }.merge(values)
  end

  # Answers a topic: what the test set, else what a DLL with nothing to say answers.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    if @fixed.key?(topic)
      fixed = @fixed[topic]
      return fixed.respond_to?(:call) ? fixed.call(request) : fixed
    end

    case topic
    when "worlds.local" then @worlds.values
    when "worlds.describe" then written(request)
    when "worlds.update" then (world = written(request)) && { "world" => world, "written" => true }
    when "worlds.added" then []
    when "worlds.data_text" then ""
    end
  end

  private

  # Writes into a world kept what a request names, as the DLL writes world.ini.
  #
  # @param request [Hash] "id" and the fields that change; "played" true for played now.
  # @return [Hash, nil] The world, nil for a folder the DLL does not keep.
  def written(request)
    world = @worlds[request["id"]]
    return nil unless world

    KEPT_FIELDS.each { |key| world[key] = request[key] unless request[key].nil? }
    world["played"] = PLAYED_AT if request["played"]
    world
  end
end

# Answers the topics of the worlds on this PC and the mod picker with the values each test sets,
# kept in $locals; a bridge answered already keeps its answers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [LocalWorldAnswers] The answers.
def answer_local_worlds(fake)
  $locals = LocalWorldAnswers.new(fake) unless $locals && $locals.fake.equal?(fake)
  $locals
end

# Puts a world on this PC as worlds.local tells it, once the rules' bridge is open.
#
# @param id [String] The folder's id.
# @param values [Hash] What differs from a plain Classic world without a directory id, as the DLL
#   tells it: such as "name", "world", "type", "difficulty", "squad" as a Hash, "raid_bosses".
# @return [MGQ_MpWorld::World] The world, as the scripts keep it.
def local_world(id, values = {})
  MGQ_MpWorld::World.new($locals.keep(id, values))
end
