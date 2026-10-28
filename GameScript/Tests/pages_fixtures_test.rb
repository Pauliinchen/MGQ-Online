#----------------------------------------------------------------
#  pages_fixtures_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Checks the stand-in of a story's pages (pages_support.rb), which the script tests answer the
# DLL's topics with, against the golden cases in fixtures/pages, which MGQOnline.Game.Tests checks
# the C# class against too, so the stand-in never drifts from the DLL.

require_relative "support"
require_relative "pages_support"

# Runs one step of a scenario on the stand-in, as MGQOnline.Game.Tests runs it on the C# class.
#
# @param pages [PagesStandIn] The stand-in.
# @param step [Hash] The step, see fixtures/pages/make_fixtures.rb.
# @param frame [Integer] The frame it runs at.
# @param teller [String] The teller's name.
# @return [Hash] What happened, as the cases record it.
def run_page_step(pages, step, frame, teller)
  sent = []
  answer = {}
  case step["op"]
  when "show"
    shown = pages.answer("pages.show", { "lines" => step["lines"], "choices" => step["choices"] || [], "face" => step["face"] || "", "index" => 0, "background" => 0,
                                         "position" => 2, "skip" => step["skip"] ? true : false }, frame)
    sent << say_of(shown) if shown && shown["told"]
  when "passed"
    done = pages.answer("pages.passed", nil, frame)
    sent << ["done", done, nil, nil] if done
  when "flush"
    told = pages.answer("pages.flush", { "skip" => step["skip"] ? true : false, "telling" => step["telling"] ? true : false, "map" => step["map"] ? true : false }, frame)
    sent << say_of(told) if told
    sent << ["done", told["id"], nil, nil] if told && told["passed"]
  when "telling" then pages.answer("pages.telling_starts", nil, frame)
  when "hear" then pages.answer("pages.hear", step.reject { |key, _| %w(op frame answer).include?(key) }.merge("name" => teller), frame)
  when "done" then pages.answer("pages.done", { "page" => step["page"] }, frame)
  when "forget" then pages.answer("pages.forget", nil, frame)
  when "next"
    nexts = pages.answer("pages.next", { "giving_way" => step["giving_way"], "sharing" => step["sharing"] ? true : false }, frame)
    answer["show"] = nexts && nexts["show"]
  when "over"
    answer["over"] = pages.answer("pages.over", { "teller" => step["teller"] ? teller : nil, "telling" => step["telling"] ? true : false, "raid" => step["raid"] ? true : false,
                                                  "giving_way" => step["giving_way"], "confirm" => step["confirm"] ? true : false, "skip" => step["skip"] ? true : false }, frame)["over"]
  when "ended" then pages.answer("pages.ended", nil, frame)
  end
  answer.merge("sent" => sent, "waiting" => pages.waiting, "mirroring" => pages.mirroring?)
end

# Writes a page told as the cases record it.
#
# @param told [Hash] The page told.
# @return [Array] "say", its id, lines and choices.
def say_of(told)
  lines = told["fields"]["lines"].split(",").map { |line| line.unpack("m0")[0].force_encoding("UTF-8") }
  choices = told["fields"]["choices"].split(",").map { |line| line.unpack("m0")[0].force_encoding("UTF-8") }
  ["say", told["id"], lines, choices]
end

PAGE_CASES["scenarios"].each do |scenario|
  pages = PagesStandIn.new
  teller = "Teller"
  frame = 0
  failure = nil
  scenario["steps"].each do |step|
    frame = step["frame"] || frame
    teller = "Another" if step["op"] == "forget"
    answer = run_page_step(pages, step, frame, teller)
    expected = step["answer"]
    failure ||= "after #{step.reject { |key, _| key == 'answer' }.inspect} it answers #{answer.inspect}, the script #{expected.inspect}" unless answer == expected
  end
  check("the pages stand-in plays #{scenario['name']} as the script did", failure, nil)
end
