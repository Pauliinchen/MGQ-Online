#----------------------------------------------------------------
#  story_choices_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Checked that the help line shows the hint of the choice under the cursor
#      Paulinchen  2026-11-06: Read the screen of choices from its component of the UI layer
#      Paulinchen  2026-11-05: Answered the outcomes offered and their notes with fixed values instead of the stand-in's rules
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# Checks the screen of the story's choices (coop_choices.rbx, show_screen and Screen) on the Mod
# Framework's window it is: "Sync story" lists the outcomes offered with the leader's route first at
# the Great Decision, turns them and shows the note of the cursor's choice, takes every outcome on
# "Bring me there", leaves the story on cancel and closes with a notice once the offer is gone; a
# choice of the player's own closed with cancel opens again only after they were busy and stand
# free, or at once when its menu scene never started or the framework refused it. The DLL offers
# fixed outcomes and notes that name the outcome asked (telling_support.rb).

require_relative "support"
require_relative "story_screens_support"

# The story the rules read: the switches and variables as arrays, no companion in the roster.
module MGQ_MpStoryState; def self.data_of(data); data; end; def self.roster_ids; []; end; end
$game_switches = []
$game_variables = []
# Whether the world is a Raid World, from $raid, and the party's leader, from $leader.
module MGQ_MpCoop
  module Scope; def self.raid?; $raid; end; end
  def self.party_leader; $leader; end
end
# Whether the player follows the leader's story, which a choice of their own asks: always here.
module MGQ_MpCoopStory; def self.follows_leader?; true; end; def self.follow_place; nil; end; end
answer_telling(FAKE)
# The outcomes offered and the note of each, which names the choice and the outcome asked.
OFFERED = { "magistea" => { "labels" => ["Defeat Lily", "Defeat Lucia"], "outcomes" => [0, 1] },
            "decision" => { "labels" => ["Angelic Dominion", "Monster Realm"], "outcomes" => [0, 1] } }
$tells.set("choices.offered") { |request| OFFERED[request["key"]] }
$tells.set("choices.note") { |request| "#{request['key']} #{request['index']} for #{request['leader']} on route #{request['route']}" }

choices = MGQ_MpCoopChoices
leader = Struct.new(:state).new({ "id" => "a", "name" => "Ana" })
taken = []
offer_gone = nil
# Opens "Sync story" for two choices, the leader on the Monarch's route, and steps into its scene.
sync = lambda do
  $scenes = []
  choices.show_screen("Sync story with Ana", [:magistea, :decision], ["Bring me there", "Cancel"], leader, 1, lambda { |answers| taken << answers.dup },
                      lambda { offer_gone })
  enter_menu
end

# Sync story: the choices' titles with the outcome picked, the leader's route first at the Great
# Decision, the cursor's hint and note.
window = sync.call
screen = screen_part(:mgq_online_story_choices)
rows = screen.send(:rows)
check("the window lists the choices under a heading, each with its outcome, the leader's route first at the Great Decision",
      [window.title, rows[0], rows[1..-1].map { |row| [row[:text], row[:value]] }],
      ["Sync story with Ana", { :heading => "Your choices" }, [["Magistea Village", "Defeat Lily"], ["The Great Decision", "Monster Realm"]]])
check("the cursor's choice has its hint from the DLL's table and the note of its outcome",
      [screen.row, screen.send(:hint_of, screen.send(:current)), screen.send(:note_of, screen.send(:current))],
      [1, TellingAnswers::TABLE["branches"][1][3], "magistea 0 for Ana on route 1"])

# The help line tells the cursor's hint once C# reports the focus on the list, which it does only
# after the window's menu scene started, and follows the cursor.
engine = Mod_Framework::UI::Engine
parts_of = lambda { |component, type| (component.is_a?(type) ? [component] : []) + Array(component.children).map { |child| parts_of.call(child, type) }.flatten }
help_line = parts_of.call(window, engine::HelpLine).first
engine::Layer.frame
engine::Tree.instance_variable_set(:@focused, parts_of.call(window, engine::List).first)
shown = [help_line.send(:current)]
screen.send(:row=, 2)
engine::Layer.frame
check("the help line shows the hint of the choice under the cursor once the list has the focus, and of the next one after a move",
      shown << help_line.send(:current), [TellingAnswers::TABLE["branches"][1][3], choices.branch(:decision)[3]])
screen.send(:row=, 1)

# Turning: Left and Right step an outcome round, Enter steps it on; the note follows.
$sounds = []
screen.send(:turn, rows[2], -1)
check("Left turns the Great Decision back, round to the first route", [choices.screen[:answers][:decision], screen.send(:rows)[2][:value]], [0, "Angelic Dominion"])
screen.send(:turn, rows[1], 1)
check("Enter turns Magistea Village on, with the cursor's sound", [choices.screen[:answers][:magistea], $sounds], [1, ["cursor", "cursor"]])
check("and its note follows", screen.send(:note_of, screen.send(:current)), "magistea 1 for Ana on route 1")

# Bring me there takes every outcome shown.
screen.send(:confirm)
check("Bring me there closes the window and takes every outcome shown", [screen_part(:mgq_online_story_choices), taken, choices.screen], [nil, [{ :magistea => 1, :decision => 0 }], nil])

# Cancel, by the button or the game's cancel key, leaves the story as it is.
window = sync.call
cancel(window)
window = sync.call
screen_part(:mgq_online_story_choices).send(:close)
check("cancel and the Cancel button leave the story as it was", [taken.size, screen_part(:mgq_online_story_choices), choices.screen], [1, nil, nil])

# The offer taken back closes the window with a notice, and an offer gone before it opens opens none.
window = sync.call
offer_gone = "Ana took the offer back."
$notices = []
window.watch_frame
check("the offer taken back closes the window and tells the player their story stays", [screen_part(:mgq_online_story_choices), $notices], [nil, ["Ana took the offer back. Your story stays as it was."]])
$scenes = []
choices.show_screen("Sync story with Ana", [:magistea], ["Bring me there", "Cancel"], leader, 1, lambda { |answers| taken << answers }, lambda { offer_gone })
check("an offer gone before the window opens opens none", [$scenes, $notices.size, taken.size], [[], 2, 1])
offer_gone = nil

# A choice of the player's own: Confirm applies it; cancel puts it off until the player was busy.
$raid = false
$leader = leader
choices.forget("next check")
choices.instance_variable_get(:@prompts) << :magistea
$scenes = []
$free = true
choices.update
window = enter_menu
screen = screen_part(:mgq_online_story_choices)
check("a choice of the player's own opens once they stand free, with Confirm alone", [window.title, screen.screen[:buttons]], ["Your own outcome", ["Confirm"]])
cancel(window)
choices.update
check("cancel puts it off while the player walks on", [$scenes.size, choices.instance_variable_get(:@prompts)], [1, [:magistea]])
$free = false
choices.update
$free = true
choices.update
check("and it opens again once they stand free after a message", $scenes.size, 2)
applied = []
choices.define_singleton_method(:apply) { |key, index, _answers = {}| applied << [key, index] }
enter_menu
screen_part(:mgq_online_story_choices).send(:confirm)
check("Confirm applies the outcome picked", [applied, choices.instance_variable_get(:@prompts)], [[[:magistea, 0]], []])

# A screen the framework refuses tells the player nothing and opens again on the next free frame;
# a load forgets its screen.
$notices = []
choices.instance_variable_get(:@prompts) << :magistea
$scenes = []
open = Mod_Framework::UI.method(:open)
Mod_Framework::UI.define_singleton_method(:open) { |*_values| nil }
choices.update
Mod_Framework::UI.define_singleton_method(:open, open)
check("a choice the framework refuses tells the player nothing and waits", [$scenes.size, choices.screen, $notices, choices.instance_variable_get(:@prompts)], [0, nil, [], [:magistea]])
choices.update
check("and opens on the next free frame", [$scenes.size, choices.screen && choices.screen[:title]], [1, "Your own outcome"])
choices.forget("a save was loaded")
check("and a load forgets its screen", [choices.screen, choices.instance_variable_get(:@prompts)], [nil, []])
