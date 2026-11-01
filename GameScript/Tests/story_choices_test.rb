#----------------------------------------------------------------
#  story_choices_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-01: Created
#
#----------------------------------------------------------------

# Checks the screen of the story's choices (coop_choices.rbx, show_screen and Screen) on the Mod
# Framework's window it is: "Sync story" lists the outcomes offered with the leader's route first at
# the Great Decision, turns them and shows the note of the cursor's choice, takes every outcome on
# "Bring me there", leaves the story on cancel and closes with a notice once the offer is gone; a
# choice of the player's own closed with cancel opens again only after they were busy and stand
# free, or at once when its menu scene never started or the framework refused it. The rules behind the outcomes and notes are ChoicesStandIn's (choices_support.rb).

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
answer_choices(FAKE)

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
# Decision, the cursor's hint and note, and the keys naming the bound cancel key.
window = sync.call
list = window.find(:mgq_online_story_choices_list)
rows = list.rows
check("the window lists the choices under a heading, each with its outcome, the leader's route first at the Great Decision",
      [window.title, rows[0], rows[1..-1].map { |row| [row[:label], row[:value]] }],
      ["Sync story with Ana", { :heading => "Your choices" }, [[ChoicesStandIn.branch("magistea")["title"], choices.labels(:magistea)[0]],
                                                                [ChoicesStandIn.branch("decision")["title"], choices.labels(:decision)[1]]]])
texts = label_texts(window)
check("the hint of the cursor's choice and the note of its outcome show",
      [texts[0], texts[1]], [choices.branch(:magistea)[3], choices.note(:magistea, 0, { :magistea => 0, :decision => 1 }, 1, "Ana")])
help = window.children.last
check("the key line names the bound cancel key", help.line.to_s.include?("#{Mod_Framework::UI.cancel_keys}: cancel"), true)

# Turning: Left and Right step an outcome round, Enter steps it on; the note follows.
$sounds = []
list.emit(:side, list.row_at(2), 2, -1)
check("Left turns the Great Decision back, round to the first route", [choices.screen[:answers][:decision], list.rows[2][:value]], [0, choices.labels(:decision)[0]])
list.emit(:submit, list.row_at(1), 1)
check("Enter turns Magistea Village on, with the cursor's sound", [choices.screen[:answers][:magistea], $sounds], [1, ["cursor", "cursor"]])
check("and its note follows", label_texts(window)[1], choices.note(:magistea, 1, { :magistea => 1, :decision => 0 }, 1, "Ana"))

# Bring me there takes every outcome shown.
buttons = window.children[-2].children
buttons[0].receive("click")
check("Bring me there closes the window and takes every outcome shown", [window.open?, taken, choices.screen, $scene.class], [false, [{ :magistea => 1, :decision => 0 }], nil, Scene_Map])

# Cancel, by the button or the game's cancel key, leaves the story as it is.
window = sync.call
cancel(window)
window = sync.call
window.children[-2].children[1].receive("click")
check("cancel and the Cancel button leave the story as it was", [taken.size, window.open?, choices.screen], [1, false, nil])

# The offer taken back closes the window with a notice, and an offer gone before it opens opens none.
window = sync.call
offer_gone = "Ana took the offer back."
$notices = []
window.watch_frame
check("the offer taken back closes the window and tells the player their story stays", [window.open?, $notices], [false, ["Ana took the offer back. Your story stays as it was."]])
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
check("a choice of the player's own opens once they stand free, with Confirm alone",
      [window.title, window.children[-2].children.map { |button| button.text }], ["Your own outcome", ["Confirm"]])
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
window = enter_menu
window.children[-2].children[0].receive("click")
check("Confirm applies the outcome picked", [applied, choices.instance_variable_get(:@prompts)], [[[:magistea, 0]], []])

# A menu scene that never started, as when a battle took its place in the same frame, lets the
# choice open again once the player stands free on the map: the map ends with another scene next,
# so the framework closes the window waiting for its menu scene. A load forgets its screen.
choices.instance_variable_get(:@prompts) << :magistea
$scenes = []
map = $scene = Scene_Map.new
choices.update
$scene = Scene_Map.new
Mod_Framework::UI::Tree.scene_ended(map)
choices.update
window = enter_menu
check("a choice whose menu scene never started opens again on the next free frame", [$scenes.size, window && window.title], [2, "Your own outcome"])
choices.forget("a save was loaded")
check("and a load forgets its screen", [choices.screen, choices.instance_variable_get(:@prompts)], [nil, []])

# A screen the framework refuses, as while another mod's window waits for its menu scene, tells
# the player nothing and opens again once the player stands free.
$notices = []
$scene = Scene_Map.new
Mod_Framework::UI::Window.new(:title => "Another mod's", :menu => true).open
map = $scene = Scene_Map.new
choices.instance_variable_get(:@prompts) << :magistea
shown = $scenes.size
choices.update
check("a choice the framework refuses tells the player nothing and waits", [$scenes.size - shown, choices.screen, $notices], [0, nil, []])
Mod_Framework::UI::Tree.scene_ended(map)
choices.update
check("and opens once the other window is gone", [$scenes.size - shown, choices.screen && choices.screen[:title]], [1, "Your own outcome"])
