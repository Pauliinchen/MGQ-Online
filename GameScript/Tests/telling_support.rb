#----------------------------------------------------------------
#  telling_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the topics of the story's telling, choices, calls, pages, scene and flow guard with the values each test sets instead of a copy of the C# rules
#                            - Handed and expected sites as plain values
#                            - Answered at the bridge's frame, the scripts' clock
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Answers the topics of the story's telling on a FakeBridge with the fixed values each test sets
# for its case: the choices (ChoiceTopics), a story's calls (GatherTopics), its pages (PageTopics),
# its scene (SceneTopics), the telling machine (the telling topics of StoryTopics) and the one guard
# of the game's flow (FlowTopics). Unless a test sets an answer, the DLL has nothing to say: no
# choice passed or asked, no call, no page, no plan, and the telling goes on as a new one without
# a lock. The choices' table is the one the DLL answers (the recorded reply in
# fixtures/choices/cases.json); a scene's change is kept and goes out alone, written and read as a
# fake line (wire_support.rb). Every rule (which choices a story passes, when a call lapses, when a
# page is over, how changes merge, which event goes on with a telling, what the guard puts back) is
# the C# tests' to cover.

require "json"
require_relative "bridge_support"
require_relative "wire_support"

# Stands in for the DLL's answers of the story's telling.
class TellingAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(choices.passed choices.prompts choices.missed choices.offered choices.endings choices.note choices.outcome choices.personal choices.skip
              choices.offer_refusal choices.lapsed choices.table
              gather.called gather.come_to gather.followed gather.ban gather.frame gather.take gather.calling_battle gather.drop_call gather.hold
              gather.drop_hold gather.holding gather.offer gather.follow_offer gather.accept gather.decline gather.forget gather.forget_offers
              pages.show pages.passed pages.flush pages.telling_starts pages.hear pages.done pages.forget pages.next pages.over pages.ended
              scene.change scene.flush scene.clear scene.take scene.check
              telling.start telling.command telling.end telling.moving telling.arrived
              flow.plan flow.stands).freeze

  # The choices' table as the DLL answers it, recorded in the choices' golden cases.
  TABLE = JSON.parse(File.read(File.expand_path("../../fixtures/choices/cases.json", __dir__), :encoding => "UTF-8"))["cases"]
              .find { |entry| entry["topic"] == "choices.table" }["reply"].freeze

  # What a topic answers unless a test sets it; a topic not listed answers nil.
  DEFAULTS = { "choices.passed" => [], "choices.prompts" => [], "choices.missed" => [], "choices.lapsed" => [], "choices.endings" => false,
               "choices.table" => TABLE, "gather.ban" => false, "gather.calling_battle" => false, "gather.drop_hold" => false,
               "scene.change" => true, "flow.stands" => false }.freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    @changes = []
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
    when "scene.change" then @changes << request
    when "scene.flush" then return flush
    when "scene.take" then return take(request)
    end
    DEFAULTS[topic]
  end

  private

  # Hands the changes kept since the last flush, each alone in its message, nil while none waits.
  #
  # @return [Array<Hash>, nil] The messages.
  def flush
    return nil if @changes.empty?

    changes = @changes
    @changes = []
    changes.map do |change|
      line = FakeLines.line(change["args"])
      { "map" => change["map"], "kind" => change["kind"], "args" => line, "changes" => [[change["kind"], line[0, 120], change["logged"]]] }
    end
  end

  # Reads a message's fake line back with no change refused, nil for a line that does not read.
  #
  # @param request [Hash] "kind" and "line".
  # @return [Hash, nil] "args" and "refusals".
  def take(request)
    values = FakeLines.parse(request["line"])
    return nil unless values

    { "args" => values, "refusals" => request["kind"] == "batch" ? [nil] * values.size : [nil] }
  end
end

# Answers the topics of the story's telling with the values each test sets, kept in $tells; a
# bridge answered already keeps its answers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [TellingAnswers] The answers.
def answer_telling(fake)
  $tells = TellingAnswers.new(fake) unless $tells && $tells.fake.equal?(fake)
  $tells
end

# Writes lines as a page's fields carry them on the wire.
#
# @param lines [Array<String>] The lines.
# @return [String] Each in Base64, joined by commas.
def page_text(lines)
  lines.map { |line| [line].pack("m0") }.join(",")
end

# Reads a line of a page as the wire carries it.
#
# @param text [String] The line in Base64.
# @return [String] The line.
def page_line(text)
  text.to_s.unpack("m0")[0].force_encoding("UTF-8")
end
