#----------------------------------------------------------------
#  telling_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Wrote the choices' table out instead of reading a recorded one
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
# a lock. The choices' table is the one the DLL answers (TABLE); a scene's change is kept and goes out alone, written and read as a
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

  # The choices' table as the DLL answers it: the story's branches, the values their choices read,
  # the Great Decision's step and routes, and how long an offer stands.
  TABLE = {
    "branches" => [
      ["side", "Alice or Ilias", 7, "Iliasville: whom Luka takes along on his journey, his side until the Great Decision."],
      ["magistea", "Magistea Village", 17, "Magistea Village: whom Luka defeats, Lily or Lucia. The other joins."],
      ["navy", "Navy or Pirates", 22, "Navy Headquarters: whether Luka helps the Navy catch the Fishy Pirates or sails with them. Either side gives him a ship."],
      ["plansect", "Plansect", 24, "Plansect: whose side Luka takes, the plants' Priestess or the insects' Queen Bee, or whether he makes peace between them."],
      ["succubus", "Succubus Village", 27, "Succubus Village: whom Luka allies with. Who joins depends on Lily or Lucia."],
      ["spider", "The Spider Princess", 31, "The Secluded Lands: whose side Luka takes, the Spider Princess or the Queen Ants."],
      ["sphinx", "The Sphinx", 31, "The Pyramid: Luka challenges the Sphinx, who joins once defeated."],
      ["decision", "The Great Decision", 40, "The Monster Lord's Castle: whose side Luka takes, which decides the route of the Final Chapter."],
    ],
    "reads" => { "s" => [4, 5, 2090, 2096, 2097, 2148, 2149, 2210, 2211, 2212, 2213, 2280, 2281, 7096, 7097], "v" => [912, 1001, 1050, 1051, 1061], "roster" => [153, 163, 167] },
    "great_decision" => 40,
    "routes" => [1141, 1142, 1143],
    "chaos_start" => [437, 12, 12, 0],
    "decision" => [{ "side" => 4, "return" => 111, "map" => 430 }, { "side" => 5, "return" => 112, "map" => 431 }, {}],
    "offer_frames" => 3600,
  }.freeze

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
