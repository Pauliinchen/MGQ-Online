#----------------------------------------------------------------
#  overview_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the World overview's models with the values each test sets instead of a copy of the C# rules
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# Answers the World overview's topics of the DLL (OverviewTopics: what the player tells the others,
# the lists of players and the World, Quests and Unlocks pages) on a FakeBridge with the fixed values
# each test sets for its case. The lists go out with a serial that moves on whenever the test sets
# others, and nil to a request that holds it, as the DLL hands them once per change. Unless a test
# sets an answer, nothing changed of what the player told, the state carries the place alone, the
# lists are empty and a page has nothing in it. Every rule (what is told, how the lists are built
# and ordered, how a page is laid out and folded) is the C# tests' to cover.

require_relative "bridge_support"

# Stands in for the DLL's answers of the World overview.
class OverviewAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(overview.tell overview.fields overview.rows overview.world overview.quests overview.unlocks overview.fold).freeze

  # The lists while the test set none.
  NO_LISTS = { "players" => [], "lines" => [], "party" => [], "raid_party" => [], "map" => [] }.freeze

  # A page with nothing in it.
  EMPTY_PAGE = { "head" => { "title" => nil, "note" => nil, "lines" => [], "entry" => nil }, "rows" => [], "picks" => [] }.freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # @return [Hash] The lists overview.rows hands out: "players", "lines", "party", "raid_party" and "map".
  attr_reader :lists

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    @lists = NO_LISTS
    @serial = 1
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

  # Sets the lists overview.rows hands out, under a new serial.
  #
  # @param lists [Hash] What differs from empty lists.
  def lists=(lists)
    @lists = NO_LISTS.merge(lists)
    @serial += 1
  end

  # Forgets the requests taken so far, so a check reads only those of its own case.
  def clear
    @asked.clear
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
    when "overview.fields" then { "place" => request }
    when "overview.rows" then request["serial"] == @serial ? nil : @lists.merge("serial" => @serial)
    when "overview.world", "overview.quests", "overview.unlocks" then EMPTY_PAGE
    end
  end
end

# Answers the World overview's topics with the values each test sets, kept in $overviews; a bridge
# answered already keeps its answers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [OverviewAnswers] The answers.
def answer_overview_models(fake)
  $overviews = OverviewAnswers.new(fake) unless $overviews && $overviews.fake.equal?(fake)
  $overviews
end

# Posts the DLL's ask to read the player's levels and story, which the next frame's drain hands on.
#
# @param fake [FakeBridge] The bridge.
def tell_overview_read(fake)
  fake.post("overview.read", true)
end
