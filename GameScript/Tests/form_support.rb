#----------------------------------------------------------------
#  form_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-05: Answered the world screen's forms with the DLL's recorded views and the values each test sets instead of the Ruby forms they were made from
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Answers the form.* topics of the world screen's forms (FormTopics in the DLL) on a FakeBridge with
# fixed views: a form opens on the view the DLL answers for its kind (recorded in
# fixtures/forms/world.json), and a test sets what a topic answers for its case. Unless a test sets
# an answer, a page keeps the view it showed last with the values handed to it, a text box takes
# its text as typed, a page sends without a problem, and the limits page shows its recorded view.
# Every rule (which fields show, what a switch changes, how a text is tidied or refused) is
# WorldFormsTests' and FormTopicsTests' to cover.

require "json"
require_relative "bridge_support"

# Stands in for the DLL's answers of the world screen's forms.
class FormAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(form.open form.view form.set form.turn form.tick form.check form.send form.close).freeze

  # The views the DLL answered as the golden cases recorded them, by the case's name.
  VIEWS = JSON.parse(File.read(File.expand_path("../../fixtures/forms/world.json", __dir__), :encoding => "UTF-8"))["forms"].each_with_object({}) do |entry, views|
    views[entry["case"]] = entry["view"].reject { |key, _| key == "problem" }
  end.freeze

  # The recorded view each kind of form opens on.
  OPENED = { "create" => "create as it opens", "edit" => "edit of a Classic world, by an admin", "rename" => "rename without a name while Discord tells none",
             "password" => "password", "join" => "join" }.freeze

  # The recorded view of the formation limits.
  LIMITS = "create with its formation limits"

  # The forms whose one text box sends them with Enter.
  SENDS_ON_ENTER = %w(rename password join).freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    @pages = {}
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Sets what a topic answers: a value, or a block that makes it of the request. A view answered
  # becomes the page's view.
  #
  # @param topic [String] The topic.
  # @param value [Object] The answer, nil to answer as before the test set one.
  # @yieldparam request [Hash] The request.
  def set(topic, value = nil, &block)
    block || !value.nil? ? @fixed[topic] = (block || value) : @fixed.delete(topic)
  end

  # Forgets the requests taken so far, so a check reads only those of its own case.
  def clear
    @asked.clear
  end

  # Makes a recorded view of the DLL's.
  #
  # @param name [String] The golden case that recorded it.
  # @param sends_on_enter [Boolean] Whether Enter in its one text box sends it.
  # @return [Hash] The view.
  def self.view(name, sends_on_enter = false)
    JSON.parse(JSON.generate(VIEWS.fetch(name))).merge("page" => "main", "sends_on_enter" => sends_on_enter)
  end

  # Answers a topic: what the test set, else what the page shows.
  #
  # @param topic [String] The topic.
  # @param request [Hash] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    if @fixed.key?(topic)
      fixed = @fixed[topic]
      reply = fixed.respond_to?(:call) ? fixed.call(request) : fixed
      keep(request, reply) if reply.is_a?(Hash) && reply["fields"] && topic != "form.check"
      return reply
    end

    case topic
    when "form.open" then keep(request, FormAnswers.view(OPENED.fetch(request["kind"]), SENDS_ON_ENTER.include?(request["kind"])))
    when "form.set"
      page_of(request)["values"][request["key"]] = request["value"]
      nil
    when "form.check" then [request["text"], nil]
    when "form.close"
      @pages.delete(request["form"])
      nil
    else page_of(request)
    end
  end

  private

  # Keeps a view as its page's.
  #
  # @param request [Hash] The request, naming the form and the page.
  # @param view [Hash] The view.
  # @return [Hash] The view.
  def keep(request, view)
    (@pages[request["form"]] ||= {})[request["page"] || "main"] = view
  end

  # Finds the view a page showed last; the limits page shows its recorded view at first.
  #
  # @param request [Hash] The request, naming the form and the page.
  # @return [Hash] The view.
  def page_of(request)
    pages = @pages[request["form"]] or raise FakeBridge::BadRequest, "No form is open in #{request['form']}."
    pages[request["page"] || "main"] ||= FormAnswers.view(LIMITS).merge("page" => request["page"])
  end
end

# Answers the form.* topics with the recorded views and the values each test sets, kept in $forms;
# a bridge answered already keeps its answers.
#
# @param fake [FakeBridge] The test's bridge.
# @return [FormAnswers] The answers.
def answer_forms(fake)
  $forms = FormAnswers.new(fake) unless $forms && $forms.fake.equal?(fake)
  $forms
end
