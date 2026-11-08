#----------------------------------------------------------------
#  make_seed.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Took the story ids of the rules from the relay's copy of the story id table
#      Paulinchen  2026-10-28: Wrote only the tables kept by hand, since the game scripts the generated tables came from are deleted
#                            - Wrote the steps of the story in free order as a rule
#                            - Wrote every chest and the chest flags of a party member's own, and the rewards the DLL hands the scripts, for the tests
#                            - Created
#
#----------------------------------------------------------------

# Writes the tables of the catch-up kept by hand as rows the relay's story tables take, one JSON
# file per table: the rules, counts and companion values the catch-up once kept as constants, from
# RULES, COUNTS and COMPANION_VALUES below, which is where they are kept now, next to this file,
# where the Node relay fills an empty table from at its start (Relay/node/story_seed.js). The
# reviewed rows of every other table are kept here as lists of admin edits (REVIEW.md), which this
# script never writes. Run it again after a rule changed:
#
#   ruby Relay/seed/story/make_seed.rb

require "json"

# Where the tables kept by hand go, which the relay seeds from.
SEED_FOLDER = __dir__

# The story's ids, from the relay's copy of the one table (MGQOnline.Game's StoryIds).
IDS = JSON.parse(File.read(File.join(__dir__, "..", "..", "core", "story_ids.json")))

# The rules of world_catchup.rbx, by the rule's name as the relay's `rules` table takes it: the
# companions none of whose joins is temporary (Alice, and Ilias with her later selves), Part 2's
# orbs, the common event that moves the story on once the player holds every orb, the main story's
# step it sets, the step the choice of a side in Iliasville leaves, the companion each side brings
# along, and the steps whose regions the world plays in an order of its own, where the catch-up
# leaves the player's return point alone: the Chaos route's free order after the Pocket Castle's
# revival, step 21 (user decision 2026-10-28).
RULES = {
  "lasting_companions" => [5, 26, 29, 30],
  "orbs" => [537, 538, 540, 541, 542],
  "orb_event" => IDS["orb_event"],
  "orbs_gathered" => IDS["orbs_gathered"],
  "side_step" => IDS["side_step"],
  "side_companions" => { "alice" => 5, "ilias" => 26 },
  "free_order" => [{ "part" => "chaos", "step" => IDS["chaos_free_order"] }],
}

# The variables that count switches: the Randolphs found (1354), one switch each, and Alice's
# Power-up (1353): the Alipheese 3rd to 14th (3204 to 3213, the 11th and 12th together in 3211),
# the Lilith sisters (7140) and the Tower of Light and Darkness (7040), 15 once Dark God's Castle 4F
# ends it (7034), counted from Saja on (1312 at 3), who sets it to 0 first.
COUNTS = [
  { "variable" => 1353,
    "weights" => [[3204, 1], [3205, 1], [3206, 1], [3207, 1], [3208, 1], [3209, 1], [3210, 1], [3211, 2], [3212, 1], [3213, 1], [7140, 1], [7040, 1]],
    "doneSwitch" => 7034, "doneValue" => 15, "since" => { "variable" => 1312, "atLeast" => 3 } },
  { "variable" => 1354, "weights" => (3101..3180).map { |id| [id, 1] }, "doneSwitch" => nil, "doneValue" => nil, "since" => nil },
]

# The least a variable holds once a companion is in the roster, which their own join stands for:
# Amira's information network.
COMPANION_VALUES = [{ "actor" => 540, "variable" => 1009, "atLeast" => 2 }]

tables = {
  "companion_values" => COMPANION_VALUES,
  "rules" => RULES.map { |rule, value| { "rule" => rule, "value" => value } },
  "counts" => COUNTS.map { |row| row.merge("weights" => row["weights"].map { |id, weight| { "switch" => id, "weight" => weight } }) },
}

tables.each do |table, rows|
  lines = rows.map { |row| "    #{JSON.generate(row)}" }
  File.write(File.join(SEED_FOLDER, "#{table}.json"), "{\n  \"source\": \"Relay/seed/story/make_seed.rb\",\n  \"rows\": [\n#{lines.join(",\n")}\n  ]\n}\n")
  puts "#{table}: #{rows.size} row(s)"
end
