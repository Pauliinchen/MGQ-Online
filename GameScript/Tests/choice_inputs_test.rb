#----------------------------------------------------------------
#  choice_inputs_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Stood in for the Mod Framework's cancel
#                            - Checked that a catch-up asks only the choices up to where the player started keeping the leader's story
#                            - Created
#
#----------------------------------------------------------------

# Checks the questions a replay asks on the decision screen (coop_choices.rbx, ask_input): the screen
# opens once the player is free on the map, and the answer of a number, an item or a present reaches
# the replay; cancel answers 0. The DLL's model of the inputs (ChoiceInputs in MGQOnline.Game) is
# stood in for by its answers alone.

require_relative "support"
require_relative "rules_support"

# Stand-ins for the game and the scripts coop_choices.rbx meets.

# The players' wheel and notices of ui_actions.rbx.
module MGQ_MpActions; LINE_COLOR = :line_color; def self.offer(_offers); end; end
# The world screen's form, which the sync screen draws with.
class Window_MpWorldForm; def initialize(*); end; end
# The base of the game's menu scenes.
class Scene_MenuBase; end
# The game's map scene, which ends when the player leaves it for a menu or a battle.
class Scene_Map; def terminate; end; end
# The game's map and its data manager, whose methods the script hooks.
class Game_Map; def update; end; end
module DataManager; def self.extract_save_contents(_contents); end; def self.setup_new_game; end; end
# The game's buttons down in this frame, kept in $buttons.
module Input; def self.repeat?(button); ($buttons || []).include?(button); end; def self.trigger?(button); repeat?(button); end; end
# Windows' key codes down in this frame, kept in $codes.
module Mod_Framework::UI::Key; def self.triggered?(code); ($codes || []).include?(code); end; end
# The Mod Framework's cancel: the game's cancel button, or the numpad's 0 with Num Lock on (0x60)
# or off (0x2D).
module Mod_Framework::UI
  def self.cancel?; ($buttons || []).include?(:B) || !(($codes || []) & [0x60, 0x2D]).empty?; end
end
# The game's scene manager: the map is shown, and the scenes called are kept in $scenes.
module SceneManager; def self.scene; Scene_Map.new; end; def self.call(scene); ($scenes ||= []) << scene; end; end
# The game's system sounds: each one played is kept in $sounds.
module Sound; %w[cursor ok cancel buzzer].each { |name| define_singleton_method("play_#{name}") { ($sounds ||= []) << name } }; end
# The world: the player stands free on the map while $free says so.
module MGQ_MpOverworldSync; def self.map_free?; $free; end; end
# The game's items, with their descriptions.
Item = Struct.new(:name, :description, :icon_index)
$data_items = { 12 => Item.new("Silver Ring", "A ring.", 1), 30 => Item.new("Old Map", "A map.", 2) }
# The game's companions.
Companion = Struct.new(:name)
$game_actors = { 5 => Companion.new("Alice") }
# The map, with its display name.
$game_map = Struct.new(:display_name).new("Iliasburg")

load_script "ui_online"
load_script "coop_choices"

# The DLL's model of the inputs, as far as its answers: confirm answers the number or the row under
# the cursor, a click the row clicked, cancel what the question names.
opened = []
fake = ($world_bridge ||= FakeBridge.new)
fake.answer("choices.input_open") do |request|
  opened << request
  spec = request["spec"]
  rows = (spec["items"] || []).map { |id, name, count, description| [id, name, count, description, false] }
  { "kind" => request["kind"], "title" => "t", "keys" => "k", "hint" => "h", "result" => "", "rows" => rows + [[0, "None", nil, "", true]],
    "digits" => spec["digits"] ? spec["value"].to_s.rjust(spec["digits"], "0").chars.map(&:to_i) : [], "cursor" => 0, "top" => 0,
    "visible" => request["visible"], "cancel" => request["kind"] == "number" ? nil : 0, "answer" => nil, "cue" => nil }
end
fake.answer("choices.input_step") do |request|
  input = request["input"]
  answer =
    case request["action"]
    when "ok" then input["kind"] == "number" ? input["digits"].join.to_i : input["rows"][input["cursor"]][0]
    when "click" then input["rows"][request["at"]][0]
    when "cancel" then input["cancel"]
    end
  input.merge("answer" => answer, "cue" => answer ? "ok" : nil)
end
MGQ_Multiplayer::Bridge.open(fake)

choices = MGQ_MpCoopChoices
answers = []
done = lambda { |answer| answers << answer }

# A number waits until the player is free, then opens the screen.
$free = false
choices.ask_input("Ana", ["\\n<Shopkeeper>How many coins", "do you put in?"], "number", { "digits" => 3, "value" => 42 }, done)
choices.update
check("a question waits while the player is not free on the map", ($scenes || []).size, 0)
$free = true
choices.update
check("and opens the screen once they are", $scenes.last, Scene_MpStoryQuestion)
choices.update
check("only once", $scenes.size, 1)
check("the speaker heads the message's lines", choices.speaker_of(choices.question[:lines]), ["Shopkeeper", ["How many coins", "do you put in?"]])
check("the place is the map's name", choices.question[:place], "Iliasburg")
choices.open_question(4)
check("the DLL gets the number's digits and value", opened.last.values_at("kind", "opener", "spec"), ["number", "Ana", { "digits" => 3, "value" => 42, "index" => 0 }])
check("cancel answers no number", choices.step_question("cancel"), nil)
answer = choices.step_question("ok")
choices.answered_question(answer)
check("confirm hands the number to the replay", answers, [42])
check("and the question is done", choices.question, nil)

# The keys on a number: the number row types digits, the numpad none; Esc and B do nothing, as in
# the game, and Numpad 0 closes the screen without an answer.
screen = Scene_MpStoryQuestion.allocate
screen.instance_variable_set(:@question, { :input => { "kind" => "number" } })
keys = lambda { |buttons, codes| $buttons, $codes = buttons, codes; screen.keys_step }
check("a digit of the number row types it", keys.call([], [0x37]), ["digit", 7, 0, false])
check("a digit of the numpad types nothing", keys.call([], [0x67]), nil)
check("Esc and B do nothing", keys.call([:B], []), nil)
check("Numpad 0 closes the number, with Num Lock on and off", [keys.call([:B], [0x60]), keys.call([], [0x2D])], [["later", 0, 0, false]] * 2)
$buttons, $codes = [], []

# A number closed with Numpad 0 waits: walking on does not reopen it; a message, a menu or a battle
# of the player's own does, once they stand free again.
choices.ask_input("Ana", ["How many?"], "number", { "digits" => 2, "value" => 0 }, done)
shown = lambda { choices.update; $scenes.size }
opened_before = shown.call
choices.put_off_question
check("a number put off stays closed while the player walks on", shown.call, opened_before)
$free = false
choices.update
$free = true
check("and opens again once they stand free after a message", shown.call, opened_before + 1)
choices.put_off_question
Scene_Map.new.terminate
check("or after a menu or a battle", shown.call, opened_before + 2)
check("the number still waits for its answer", answers, [42])

# A key item: the player's items with their descriptions, picked or none.
choices.ask_input(nil, [], "item", { "items" => [[12, "Silver Ring", 1], [30, "Old Map", 2]] }, done)
choices.open_question(4)
check("the item's description goes with it", opened.last["spec"]["items"], [[12, "Silver Ring", 1, "A ring."], [30, "Old Map", 2, "A map."]])
choices.answered_question(choices.step_question("click", 1))
choices.ask_input(nil, [], "item", { "items" => [[12, "Silver Ring", 1]] }, done)
choices.open_question(4)
choices.answered_question(choices.step_question("cancel"))
check("a click answers the item, cancel answers 0", answers.last(2), [30, 0])

# A present for a companion: the companion's name goes to the DLL; no present answers 0.
choices.ask_input("Ana", [], "present", { "actor" => 5, "items" => [[12, "Silver Ring", 1]] }, done)
choices.open_question(4)
check("a present names the companion", opened.last["companion"], "Alice")
choices.answered_question(choices.step_question("ok"))
choices.ask_input("Ana", [], "present", { "actor" => 5, "items" => [[12, "Silver Ring", 0]], "result" => "Alice is pleased." }, done)
choices.open_question(4)
choices.answered_question(choices.step_question("cancel"))
check("the present given, then no present", answers.last(2), [12, 0])

# A choice asked as before goes through the same screen.
choices.ask("Ana", ["Will you help?"], ["Yes", "No"], done)
choices.open_question(4)
check("ask is a choice with the labels", opened.last.values_at("kind", "spec"), ["choice", { "labels" => ["Yes", "No"], "index" => 0 }])

# A save loaded drops the question; the replay asks again when it takes the run.
choices.forget("a save was loaded")
check("forgetting drops the question", choices.question, nil)

# A choice a stream's run hands over is the replay's: a catch-up asks only those up to where the
# stream began handing runs, in a Classic party where the player started keeping the leader's story,
# that place included.
answer_choices(fake)
module MGQ_MpCoop; module Scope; def self.raid?; false; end; end; end
module MGQ_MpCoopStory; def self.follow_place; [17, 0, 0, 0]; end; end
check("a catch-up asks only the choices up to where the player started keeping the leader's story", choices.passed(5, 40, [], [], []), [:side, :magistea])
