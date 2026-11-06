#----------------------------------------------------------------
#  choice_inputs_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Dropped the number, key item and present questions, and walked the question's flow on a choice
#                            - Checked that the question shows the opener's name over the message, without why it is asked or the place
#                            - Checked that forgetting the question closes its window
#                            - Read the question's screen from its component of the UI layer
#      Paulinchen  2026-11-05: Answered the model of each input with fixed values per case instead of from a copy of the C# one
#                            - Answered the choices a catch-up passes with a fixed answer and checked where the stream began goes with the request
#      Paulinchen  2026-11-01: Ended the map before its menu scene started, as the game does when another scene takes its place
#                            - Played the question on the Mod Framework's window it now is
#                            - Checked that a question whose menu scene never started opens again
#                            - Checked that cancel puts a number and a choice without cancel off and answers a choice's own cancel
#                            - Checked that a label's names are filled in
#      Paulinchen  2026-10-31: Stood in for the Mod Framework's cancel
#                            - Checked that a catch-up asks only the choices up to where the player started keeping the leader's story
#                            - Created
#
#----------------------------------------------------------------

# Checks the choices a replay asks (coop_choices.rbx, ask, StoryQuestion): the window opens in a
# menu scene of its own once the player is free on the map; a row answers; cancel answers what the
# choice's cancel answers, or puts a choice without cancel off until the player was busy and stands
# free again. The DLL's model of the question (ChoiceInputs in MGQOnline.Game, ChoiceInputsTests)
# answers with the fixed model each case sets.

require_relative "support"
require_relative "story_screens_support"

# The game's companions.
Companion = Struct.new(:name)
$game_actors = { 5 => Companion.new("Alice") }

# The DLL's model of the question open, which each case sets, and the requests it got.
$input_model = nil
opened = []
FAKE.answer("choices.input_open") { |request| opened << request; $input_model }

# Writes the DLL's model of a choice as choices.input_open answers it, the first row picked.
#
# @param rows [Array<Array>] Each row's answer, text and whether it is dim.
# @param cancel [Integer, nil] What cancel answers, nil to answer later.
# @return [Hash] The model.
def input_model(rows, cancel)
  { "title" => "Ana", "keys" => [["Enter", "answer"], ["cancel", cancel.nil? ? "answer later" : "Cancel"]], "hint" => "Pick your answer.",
    "rows" => rows, "index" => 0, "cancel" => cancel }
end

# Writes a row of a choice's label.
#
# @param place [Integer] The label's place.
# @param text [String] The label.
# @return [Array] The row.
def label_row(place, text)
  [place, text, false]
end

choices = MGQ_MpCoopChoices
answers = []
done = lambda { |answer| answers << answer }
# Lets the map run a frame, the player free on it or not.
frame = lambda { |free| $free = free; choices.update }

# A choice waits until the player is free, then opens its window in a menu scene of its own.
$scenes = []
$input_model = input_model([label_row(0, "Yes"), label_row(1, "No")], 1)
choices.ask("Ana", ["\\n<Shopkeeper>Will you buy", "the lamp?"], ["Yes", "No"], done, 1)
frame.call(false)
check("a question waits while the player is not free on the map", $scenes.size, 0)
frame.call(true)
frame.call(true)
check("and opens its screen once they are, only once", $scenes.size, 1)
window = enter_menu
check("the window opens in the menu scene the framework called", [window && window.open?, window && window.title], [true, "Ana"])
check("the DLL gets the choice's labels and what cancel answers", opened.last.values_at("opener", "spec"), ["Ana", { "labels" => ["Yes", "No"], "cancel" => 1, "index" => 0 }])
check("under the opener's name as the title: the speaker and the message's lines",
      label_texts(window).first(3), ["Shopkeeper", "Will you buy", "the lamp?"])
check("a choice lists its labels", screen_part(:mgq_online_story_question).send(:rows).map { |row| row[:text] }, ["Yes", "No"])
screen_part(:mgq_online_story_question).send(:close, screen_part(:mgq_online_story_question).send(:rows)[0][:data])
check("a row picked answers its place and the window closes", [answers, screen_part(:mgq_online_story_question), $scene.class], [[0], nil, Scene_Map])
check("and the question is done", choices.question, nil)

# Cancel puts a choice without cancel off: walking on does not reopen it; a message, a menu or a
# battle of the player's own does, once they stand free again.
$input_model = input_model([label_row(0, "Yes"), label_row(1, "No")], nil)
choices.ask("Ana", ["Will you help?"], ["Yes", "No"], done)
frame.call(true)
cancel(enter_menu)
check("cancel closes a choice without cancel unanswered", [answers, choices.question[:later]], [[0], true])
shown = $scenes.size
frame.call(true)
check("a choice put off stays closed while the player walks on", $scenes.size, shown)
frame.call(false)
frame.call(true)
check("and opens again once they stand free after a message", $scenes.size, shown + 1)
cancel(enter_menu)
Scene_Map.new.terminate
frame.call(true)
window = enter_menu
check("or after a menu or a battle", window && window.open?, true)
choices.forget("next check")

# A choice with its own cancel branch answers it on cancel, from a dim last row.
$input_model = input_model([label_row(0, "Sword"), label_row(1, "Shield"), [2, "Cancel", true]], 2)
choices.ask("Ana", [], ["Sword", "Shield"], done, 2)
frame.call(true)
window = enter_menu
check("a choice with its own cancel branch shows it dim and last", screen_part(:mgq_online_story_question).send(:rows).last, { :text => "Cancel", :color => :dim, :data => 2 })
cancel(window)
check("and cancel answers the branch", answers.last, 2)

# A scene change closes the window without an answer, which then opens again at once.
$input_model = input_model([label_row(0, "Yes"), label_row(1, "No")], 1)
choices.ask("Ana", [], ["Yes", "No"], done, 1)
frame.call(true)
enter_menu.close(:scene)
frame.call(true)
check("a window closed by a scene change opens again once the player stands free", enter_menu && true, true)

# A save loaded drops the question and closes its window; the replay asks again when it takes the run.
choices.forget("a save was loaded")
check("forgetting drops the question and closes its window, back on the map", [choices.question, screen_part(:mgq_online_story_question).nil?, $scene.class], [nil, true, Scene_Map])

# A choice a stream's run hands over is the replay's: a catch-up hands the DLL where the stream
# began handing runs, in a Classic party where the player started keeping the leader's story, and
# asks the choices the DLL names.
answer_telling(FAKE)
module MGQ_MpCoop; module Scope; def self.raid?; false; end; end; end
module MGQ_MpCoopStory; def self.follow_place; [17, 0, 0, 0]; end; end
$tells.set("choices.passed", %w(side magistea))
check("a catch-up hands the DLL where the player started keeping the leader's story and asks the choices it names",
      [choices.passed(5, 40, [], [], []), $tells.asked("choices.passed").last.values_at("from", "to", "start")], [[:side, :magistea], [5, 40, [17, 0, 0, 0]]])

# A label's names are filled in as the game's windows fill them, its other codes kept.
class Window_Base; def convert_escape_characters(text); text.gsub("\\", "\e").gsub(/\eN\[(\d+)\]/i) { $game_actors[$1.to_i].name }; end; end
choices.forget("next check")
$input_model = input_model([label_row(0, "Help Alice"), label_row(1, '\C[2]Leave\C[0]')], 1)
choices.ask("Ana", [], ['Help \N[5]', '\C[2]Leave\C[0]'], done, 1)
$free = true
choices.show_question
check("a label's names are filled in, its other codes kept", opened.last["spec"]["labels"], ["Help Alice", '\C[2]Leave\C[0]'])
