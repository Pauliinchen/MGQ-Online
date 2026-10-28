#----------------------------------------------------------------
#  make_seed.rb
#
#  Changelog:
#      Paulinchen  2026-10-28: Wrote the steps of the story in free order as a rule
#                            - Wrote every chest and the chest flags of a party member's own, and the rewards the DLL hands the scripts, for the tests
#                            - Created
#
#----------------------------------------------------------------

# Writes the tables of the catch-up as rows the relay's story tables take, one JSON file per table:
# the rules, counts and companion values the catch-up once kept as constants, from RULES, COUNTS and
# COMPANION_VALUES below, which is where they are kept now, next to this file, where the Node relay
# fills an empty table from at its start (Relay/node/story_seed.js); and the tables of
# world_catchup_data.rbx and coop_story_rewards.rbx of GameScript/Multiplayer/Scripts, as the admins
# would add their rows (Relay/README.md "Catch-up tables"), into fixtures/catchup/generated, where
# the tests of the DLL and the scripts read them. The generated tables never go into the seed: the
# reviewed rows of each table are kept there as lists of admin edits (REVIEW.md), which this script
# never writes. It also writes the rewards a party member catches up with as
# the DLL hands them to the scripts, from the constants of coop_story_rewards.rbx, into
# fixtures/catchup/party_rewards.json, which MGQOnline.Game.Tests holds PartyRewards against over
# the generated tables. Run it again after raid_data.rb or story_rewards.rb of
# MGQ-Paradox-Event-Checker wrote new data, or after a rule changed:
#
#   ruby Relay/seed/story/make_seed.rb

require "json"
require_relative "../../../fixtures/catchup/relay_rows"

# The repository.
ROOT = File.expand_path("../../..", __dir__)

# The scripts the tables come from.
SCRIPTS = File.join(ROOT, "GameScript", "Multiplayer", "Scripts")

# Where the tables kept by hand go, which the relay seeds from.
SEED_FOLDER = __dir__

# Where the generated tables go, for the tests.
GENERATED_FOLDER = File.join(ROOT, "fixtures", "catchup", "generated")

# The tables kept by hand below, the only seed files this script writes.
HAND_KEPT = %w(rules counts companion_values)

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
  "orb_event" => 330,
  "orbs_gathered" => 32,
  "side_step" => 7,
  "side_companions" => { "alice" => 5, "ilias" => 26 },
  "free_order" => [{ "part" => "chaos", "step" => 21 }],
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

# What the relay's rows call a reward's kind, by the Ruby kind.
REWARD_KINDS = { :skill => "skill", :i => "item", :w => "weapon", :a => "armor" }

# What the relay's rows call a setting's kind, by the Ruby kind.
SETTING_KINDS = { :encounters => "encounters", :v => "variable", :s => "switch" }

# The vehicles by the number the Ruby rows give them.
VEHICLES = %w(boat ship airship)

load File.join(SCRIPTS, "world_catchup_data.rbx")
load File.join(SCRIPTS, "coop_story_rewards.rbx")

# Writes a mark as the relay takes it: its kind as text.
#
# @param mark [Array] [:s, switch], [:v, variable, at least] or [:ss, map, event, letter].
# @return [Array] The mark.
def mark_of(mark)
  [mark[0].to_s] + mark[1..-1]
end

# Writes a row's place in the story.
#
# @param row [Struct] A row with site, part, step, side and marks.
# @return [Hash] The place's fields.
def place_of(row)
  { "site" => row.site, "part" => row.part, "step" => row.step, "side" => row.side && row.side.to_s, "marks" => row.marks.map { |mark| mark_of(mark) } }
end

# Numbers the rows of an ordered table, ten apart so an admin can put one between.
#
# @param rows [Array<Hash>] The rows in the story's order.
# @return [Array<Hash>] The rows with their order.
def ordered(rows)
  rows.each_with_index.map { |row, index| row.merge("order" => (index + 1) * 10) }
end

# Names the sites of the side events, which coop_story_rewards.rbx keeps as a comment above each
# group, in the groups' order.
#
# @return [Array<String>] The sites.
def side_event_sites
  text = File.read(File.join(SCRIPTS, "coop_story_rewards.rbx"), :encoding => "UTF-8")
  groups = text[/^  GROUPS = \[\n.*?\n  \]/m] or raise "GROUPS not found"
  groups.scan(/^    # ((?:map:\d+:\d+|ce:\d+))$/).flatten
end

# Writes what one side of a side event gives.
#
# @param side [Hash] :skills and :actors.
# @return [Hash] skills and companions.
def side_rewards(side)
  { "skills" => side[:skills], "companions" => side[:actors] }
end

# Writes the event rewards of coop_story_rewards.rbx as rows.
#
# @return [Array<Hash>] The rows.
def event_rewards
  rewards = MGQ_MpCoopStoryRewards
  rows = rewards::SKILLS.map do |id|
    { "kind" => "skill", "id" => id, "most" => nil, "sided" => rewards::SIDED[:skills].include?(id), "route" => rewards::ROUTE[:skills].include?(id), "final" => rewards::FINAL[:skills].include?(id) }
  end
  rows.concat(rewards::ACTORS.map do |id|
    { "kind" => "companion", "id" => id, "most" => nil, "sided" => rewards::SIDED[:actors].include?(id), "route" => rewards::ROUTE[:actors].include?(id), "final" => rewards::FINAL[:actors].include?(id) }
  end)
  rows.concat(rewards::ITEMS.map do |key, most|
    { "kind" => REWARD_KINDS[key[0].to_sym], "id" => key[1..-1].to_i, "most" => most, "sided" => false, "route" => false, "final" => rewards::FINAL[:items].include?(key) }
  end)
end

data = MGQ_MpWorldCatchupData
sites = side_event_sites
raise "#{sites.size} sites for #{MGQ_MpCoopStoryRewards::GROUPS.size} groups" unless sites.size == MGQ_MpCoopStoryRewards::GROUPS.size

tables = {
  "parts" => ordered(data::PARTS.map { |row| { "id" => row.id, "name" => row.name, "ending" => row.ending.map { |mark| mark_of(mark) }, "gate" => row.gate } }),
  "joins" => ordered(data::JOINS.map { |row| { "actor" => row.actor, "persona" => row.persona }.merge(place_of(row)).merge("gate" => row.gate, "rule" => row.rule.to_s, "index" => row.index, "ran" => row.ran ? true : false) }),
  "removals" => ordered(data::REMOVALS.map { |row| { "actor" => row.actor, "persona" => row.persona }.merge(place_of(row)).merge("first" => row.first ? true : false, "index" => row.index) }),
  "key_items" => ordered(data::KEY_ITEMS.map { |row| { "item" => row.item, "amount" => row.amount }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "chests" => ordered(data::CHESTS.map { |row| { "key" => "ss#{row.key[0]}.#{row.key[1]}.#{row.key[2]}", "items" => row.items, "part" => row.part, "step" => row.step, "flags" => Array(row.flags) } }),
  "rewards" => ordered(data::REWARDS.map { |row| { "kind" => REWARD_KINDS.fetch(row.kind), "id" => row.id, "amount" => row.amount }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "lessons" => ordered(data::LESSONS.map { |row| { "actor" => row.actor, "skill" => row.skill }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "class_levels" => ordered(data::CLASS_LEVELS.map { |row| { "actor" => row.actor, "class" => row.class_id, "level" => row.level }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "actor_changes" => ordered(data::ACTOR_CHANGES.map { |row| { "actor" => row.actor, "calls" => row.calls.map { |name, ids, once| [name.to_s, ids, once ? true : false] }, "gate" => row.gate }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "settings" => ordered(data::SETTINGS.map { |row| { "kind" => SETTING_KINDS.fetch(row.kind), "id" => row.id, "value" => row.value }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "vehicles" => ordered(data::VEHICLES.map { |row| { "vehicle" => VEHICLES.fetch(row.vehicle) }.merge(place_of(row)).merge("ran" => row.ran ? true : false) }),
  "warp_free_maps" => data::WARP_FREE_MAPS.map { |map| { "map" => map } },
  "makina" => data::MAKINA.map { |row| { "item" => row.item, "level" => row.level, "site" => row.site } },
  "prize_variables" => data::PRIZE_VARIABLES.map { |id| { "variable" => id } },
  "companion_values" => COMPANION_VALUES,
  "rules" => RULES.map { |rule, value| { "rule" => rule, "value" => value } },
  "counts" => COUNTS.map { |row| row.merge("weights" => row["weights"].map { |id, weight| { "switch" => id, "weight" => weight } }) },
  "event_rewards" => event_rewards,
  "side_events" => MGQ_MpCoopStoryRewards::GROUPS.each_with_index.map do |group, index|
    { "site" => sites[index], "alice" => side_rewards(group[:alice]), "ilias" => side_rewards(group[:ilias]), "choice" => group[:choice] ? true : false,
      "marks" => group[:marks].map { |page| page.map { |mark| mark_of(mark) } } }
  end,
  "party_chests" => MGQ_MpCoopStoryRewards::CHESTS.map { |key| { "key" => "ss#{key[0]}.#{key[1]}.#{key[2]}" } },
  "chest_flags" => MGQ_MpCoopStoryRewards::CHEST_FLAGS.map { |id| { "switch" => id } },
}

# Names the commit a script's data was last written in, which the seed names as its source.
#
# @param name [String] The script's file name.
# @return [String] The commit, short.
def written_at(name)
  `git -C "#{ROOT}" log -1 --format=%h -- "GameScript/Multiplayer/Scripts/#{name}"`.strip
end

sources = {
  "event_rewards" => "coop_story_rewards.rbx", "side_events" => "coop_story_rewards.rbx", "party_chests" => "coop_story_rewards.rbx", "chest_flags" => "coop_story_rewards.rbx",
  "rules" => "make_seed.rb", "counts" => "make_seed.rb", "companion_values" => "make_seed.rb",
}
Dir.mkdir(GENERATED_FOLDER) unless File.directory?(GENERATED_FOLDER)
tables.each do |table, rows|
  script = sources.fetch(table, "world_catchup_data.rbx")
  source = script == "make_seed.rb" ? "Relay/seed/story/make_seed.rb" : "GameScript/Multiplayer/Scripts/#{script} at #{written_at(script)}"
  folder = HAND_KEPT.include?(table) ? SEED_FOLDER : GENERATED_FOLDER
  lines = rows.map { |row| "    #{JSON.generate(row)}" }
  File.write(File.join(folder, "#{table}.json"), "{\n  \"source\": #{JSON.generate(source)},\n  \"rows\": [\n#{lines.join(",\n")}\n  ]\n}\n")
  puts "#{table}: #{rows.size} row(s) into #{File.basename(folder)}"
end

# The rewards as the DLL hands them to the scripts, from the constants themselves.
party = CatchupRelayRows.party_rewards(MGQ_MpCoopStoryRewards, sites)
fields = party.map { |field, value| "    #{JSON.generate(field)}: #{JSON.generate(value)}" }
File.write(File.join(ROOT, "fixtures", "catchup", "party_rewards.json"),
           "{\n  \"source\": #{JSON.generate("GameScript/Multiplayer/Scripts/coop_story_rewards.rbx at #{written_at('coop_story_rewards.rbx')}")},\n  \"rewards\": {\n#{fields.join(",\n")}\n  }\n}\n")
puts "party rewards into #{File.join('fixtures', 'catchup', 'party_rewards.json')}"
