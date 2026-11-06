#----------------------------------------------------------------
#  choice_inputs_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-06: Checked that forgetting the question closes its window
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

# Checks the questions a replay asks (coop_choices.rbx, ask_input, StoryQuestion): the window opens
# in a menu scene of its own once the player is free on the map; a row, the number or the Answer
# button answer; cancel answers what the game's window answers, or puts a number and a choice without
# cancel off until the player was busy and stands free again. The DLL's model of the inputs
# (ChoiceInputs in MGQOnline.Game, ChoiceInputsTests) answers with the fixed model each case sets.

require_relative "support"
require_relative "story_screens_support"

# The game's items, with their descriptions.
Item = Struct.new(:name, :description, :icon_index)
$data_items = { 12 => Item.new("Silver Ring", "A ring.", 1), 30 => Item.new("Old Map", "A map.", 2) }
# The game's companions.
Companion = Struct.new(:name)
$game_actors = { 5 => Companion.new("Alice") }
# The map, with its display name.
$game_map = Struct.new(:display_name).new("Iliasburg")

# The DLL's model of the input open, which each case sets, and the requests it got.
$input_model = nil
opened = []
FAKE.answer("choices.input_open") { |request| opened << request; $input_model }

# Writes the DLL's model of an input as choices.input_open answers it, the first row picked.
#
# @param kind [String] "number", "choice", "item" or "present".
# @param rows [Array<Array>] Each row's answer, text, count, hint and whether it is dim.
# @param cancel [Integer, nil] What cancel answers, nil to answer later.
# @param fields [Hash] The fields that differ, such as the digits.
# @return [Hash] The model.
def input_model(kind, rows, cancel, fields = {})
  { "kind" => kind, "title" => "Ana's event", "keys" => [["Enter", "answer"], ["cancel", cancel.nil? ? "answer later" : "none"]], "hint" => rows.empty? ? "No numpad." : rows[0][3],
    "rows" => rows, "digits" => 0, "value" => 0, "index" => 0, "cancel" => cancel }.merge(fields)
end

# Writes a row of a choice's label.
#
# @param place [Integer] The label's place.
# @param text [String] The label.
# @return [Array] The row.
def label_row(place, text)
  [place, text, nil, "Pick your answer.", false]
end

# The row that answers no item.
NONE_ROW = [0, "None", nil, "", true]

choices = MGQ_MpCoopChoices
answers = []
done = lambda { |answer| answers << answer }
# Lets the map run a frame, the player free on it or not.
frame = lambda { |free| $free = free; choices.update }

# A number waits until the player is free, then opens its window in a menu scene of its own.
$scenes = []
$input_model = input_model("number", [], nil, "digits" => 3, "value" => 42)
choices.ask_input("Ana", ["\\n<Shopkeeper>How many coins", "do you put in?"], "number", { "digits" => 3, "value" => 42 }, done)
frame.call(false)
check("a question waits while the player is not free on the map", $scenes.size, 0)
frame.call(true)
frame.call(true)
check("and opens its screen once they are, only once", $scenes.size, 1)
window = enter_menu
check("the window opens in the menu scene the framework called", [window && window.open?, window && window.title], [true, "Ana's event"])
check("the DLL gets the number's digits and value", opened.last.values_at("kind", "opener", "spec"), ["number", "Ana", { "digits" => 3, "value" => 42, "index" => 0 }])
check("under the title: why, the place, the speaker and the message's lines, the hint",
      label_texts(window).first(5), ["Your answer changes your own game.", "Iliasburg", "Shopkeeper", "How many coins", "do you put in?"])
question = screen_part(:mgq_online_story_question)
check("the number starts at the variable's value, at most as many nines as its digits", [question.number, question.send(:most)], [42, 999])
question.send(:close, 42)
check("the number answered goes to the replay and the window closes", [answers, screen_part(:mgq_online_story_question), $scene.class], [[42], nil, Scene_Map])
check("and the question is done", choices.question, nil)

# Cancel puts a number off: walking on does not reopen it; a message, a menu or a battle of the
# player's own does, once they stand free again, with the same digits.
$input_model = input_model("number", [], nil, "digits" => 2, "value" => 7)
choices.ask_input("Ana", ["How many?"], "number", { "digits" => 2, "value" => 7 }, done)
frame.call(true)
cancel(enter_menu)
check("cancel closes a number without an answer", [answers, choices.question[:later]], [[42], true])
shown = $scenes.size
frame.call(true)
check("a number put off stays closed while the player walks on", $scenes.size, shown)
frame.call(false)
frame.call(true)
check("and opens again once they stand free after a message", $scenes.size, shown + 1)
window = enter_menu
check("with the same number", screen_part(:mgq_online_story_question).number, 7)
cancel(window)
Scene_Map.new.terminate
frame.call(true)
window = enter_menu
check("or after a menu or a battle", window && window.open?, true)
screen_part(:mgq_online_story_question).number = 9
screen_part(:mgq_online_story_question).send(:close, screen_part(:mgq_online_story_question).number)
check("the Answer button answers the number shown", answers.last, 9)

# A choice without cancel is put off as a number is; one with its own branch answers it on cancel,
# from a dim last row.
$input_model = input_model("choice", [label_row(0, "Yes"), label_row(1, "No")], nil)
choices.ask("Ana", ["Will you help?"], ["Yes", "No"], done)
frame.call(true)
window = enter_menu
check("a choice lists its labels", screen_part(:mgq_online_story_question).send(:rows).map { |row| row[:text] }, ["Yes", "No"])
cancel(window)
check("cancel puts a choice without cancel off", [answers.last, choices.question[:later]], [9, true])
choices.forget("next check")
$input_model = input_model("choice", [label_row(0, "Sword"), label_row(1, "Shield"), [2, "Cancel", nil, "Pick your answer.", true]], 2)
choices.ask("Ana", [], ["Sword", "Shield"], done, 2)
frame.call(true)
window = enter_menu
check("a choice with its own cancel branch shows it dim and last", screen_part(:mgq_online_story_question).send(:rows).last, { :text => "Cancel", :color => :dim, :data => 2, :hint => "Pick your answer." })
cancel(window)
check("and cancel answers the branch", answers.last, 2)
$input_model = input_model("choice", [label_row(0, "Yes"), label_row(1, "No")], 1)
choices.ask("Ana", [], ["Yes", "No"], done, 1)
frame.call(true)
enter_menu
screen_part(:mgq_online_story_question).send(:close, screen_part(:mgq_online_story_question).send(:rows)[0][:data])
check("a row picked answers its place", answers.last, 0)

# A key item: the player's items with their descriptions, icons and counts; cancel answers none.
$input_model = input_model("item", [[12, "Silver Ring", 1, "A ring.", false], [30, "Old Map", 2, "A map.", false], NONE_ROW], 0)
choices.ask_input(nil, [], "item", { "items" => [[12, "Silver Ring", 1], [30, "Old Map", 2]] }, done)
frame.call(true)
window = enter_menu
check("the item's description goes with it", opened.last["spec"]["items"], [[12, "Silver Ring", 1, "A ring."], [30, "Old Map", 2, "A map."]])
check("an item's row has its icon, its count and its description for the help line", screen_part(:mgq_online_story_question).send(:rows).first, { :text => "Silver Ring", :data => 12, :hint => "A ring.", :icon => 1, :right => "x1" })
cancel(window)
check("cancel answers no item", answers.last, 0)

# A present for a companion: the companion's name goes to the DLL; the row picked is given.
$input_model = input_model("present", [[12, "Silver Ring", 1, "A ring.", false], NONE_ROW], 0)
choices.ask_input("Ana", [], "present", { "actor" => 5, "items" => [[12, "Silver Ring", 1]] }, done)
frame.call(true)
enter_menu
check("a present names the companion", opened.last["companion"], "Alice")
screen_part(:mgq_online_story_question).send(:close, screen_part(:mgq_online_story_question).send(:rows)[0][:data])
check("the present picked is given", answers.last, 12)

# A scene change closes the window without an answer, which then opens again at once.
$input_model = input_model("item", [NONE_ROW], 0)
choices.ask_input("Ana", [], "item", { "items" => [] }, done)
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
$input_model = input_model("choice", [label_row(0, "Help Alice"), label_row(1, '\C[2]Leave\C[0]')], 1)
choices.ask("Ana", [], ['Help \N[5]', '\C[2]Leave\C[0]'], done, 1)
$free = true
choices.show_question
check("a label's names are filled in, its other codes kept", opened.last["spec"]["labels"], ["Help Alice", '\C[2]Leave\C[0]'])
