#----------------------------------------------------------------
#  form_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# The form.* topics of the world screen's forms (FormTopics in the DLL), answered by FakeBridge from
# fixtures/forms/form_prototype.rb, the Ruby forms the DLL's WorldForms were made from. The prototype
# is checked against every golden case of fixtures/forms/world.json as this file loads, which the C#
# forms pass too, so the stand-in cannot drift from what the DLL answers.

require "json"
require_relative "../../fixtures/forms/form_prototype"

# The golden cases of the world screen's forms.
FORM_CASES = JSON.parse(File.read(File.expand_path("../../fixtures/forms/world.json", __dir__), :encoding => "UTF-8"))

FORM_CASES["forms"].each do |entry|
  shown = FormPrototype.view_of(FormPrototype.act(FormPrototype.open(entry["open"]), entry["steps"]))
  raise "the form stand-in shows #{entry['case']} otherwise than the golden case" if shown != entry["view"]
end
FORM_CASES["checks"].each do |entry|
  form = FormPrototype.open(entry["open"])
  answer = form.check(form.fields.find { |field| field.key.to_s == entry["key"] }, entry["text"])
  raise "the form stand-in checks #{entry['text'].inspect} otherwise than the golden case" if answer != entry["answer"]
end

# The forms the stand-in holds, by slot, as FormTopics does.
class FakeForms
  # The forms whose one text box sends them with Enter.
  SENDS_ON_ENTER = %w(rename password join)

  # Creates the stand-in with no form open.
  def initialize
    @forms = {}
  end

  # Answers the form.* topics.
  #
  # @param fake [FakeBridge] The bridge.
  def answer(fake)
    fake.answer("form.open") { |request| open(request) }
    fake.answer("form.view") { |request| @forms[request["form"]] && view(request) }
    fake.answer("form.set") { |request| page_of(request)[request["key"].to_sym] = request["value"]; nil }
    fake.answer("form.turn") { |request| page_of(request).turn(field_of(request), request["step"]); view(request) }
    fake.answer("form.tick") { |request| page_of(request).tick(field_of(request).key); view(request) }
    fake.answer("form.check") { |request| know(request); page_of(request).check(field_of(request), request["text"]) }
    fake.answer("form.send") { |request| send_page(request) }
    fake.answer("form.close") { |request| @forms.delete(request["form"]); nil }
  end

  private

  # Opens a form in a slot, as FormTopics does.
  #
  # @param request [Hash] The request.
  # @return [Hash] The view of its main page.
  def open(request)
    case_request = request.merge("world" => request["world"] && world_of(request["world"]))
    @forms[request["form"]] = [FormPrototype.open(case_request), request["kind"]]
    view(request)
  end

  # Turns the world an edit opens on into the prototype's listed world.
  #
  # @param world [Hash] The world as the scripts send it.
  # @return [Hash] The world as the prototype reads it.
  def world_of(world)
    world.merge("settings" => world["shared"] ? "shared" : "", "type" => world["raid"] ? "raid" : "classic")
  end

  # Sends a page: its first problem, or the page tidied as the world screen tidied it before.
  #
  # @param request [Hash] The request.
  # @return [Hash] The problem or the view.
  def send_page(request)
    know(request)
    page = page_of(request)
    index, reason = page.problem
    return { "problem" => [page.fields[index].key.to_s, reason] } if reason

    page.fields.each { |field| page[field.key] = page.check(field, page[field.key].to_s)[0] if field.typed? && page.enabled?(field) }
    view(request)
  end

  # Takes the facts a request names.
  #
  # @param request [Hash] The request.
  def know(request)
    FormPrototype.discord = request["facts"].include?("discord") if request["facts"]
  end

  # Writes a page's view, as FormTopics does.
  #
  # @param request [Hash] The request.
  # @return [Hash] The view.
  def view(request)
    page = page_of(request)
    shown = FormPrototype.view_of(page)
    shown.delete("problem")
    typed = page.fields.count { |field| field.typed? }
    shown.merge("page" => request["page"] || "main", "sends_on_enter" => SENDS_ON_ENTER.include?(@forms[request["form"]][1]) && typed == 1)
  end

  # Finds the page a request names.
  #
  # @param request [Hash] The request.
  # @return [FormPrototype::Form] The page.
  def page_of(request)
    form = (@forms[request["form"]] or raise FakeBridge::BadRequest, "No form is open in #{request['form']}.")[0]
    request["page"] == "limits" ? form.limits : form
  end

  # Finds the shown field a request names.
  #
  # @param request [Hash] The request.
  # @return [FormPrototype::Form::Field] The field.
  def field_of(request)
    page_of(request).fields.find { |field| field.key.to_s == request["key"] } or raise FakeBridge::BadRequest, "No field #{request['key']}."
  end
end

# Answers the form.* topics from the prototype.
#
# @param fake [FakeBridge] The bridge.
def answer_forms(fake)
  FakeForms.new.answer(fake)
end
