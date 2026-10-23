#----------------------------------------------------------------
#  story_support.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# The DLL's side of a Raid World's story on the relay's tracks (StoryTopics) for the script tests:
# the story topics answered by FakeBridge, what the scripts staged kept, and the tables the DLL
# hands out, among them the story mapping of fixtures/story/classes.json written as the DLL writes
# it (StoryTopicsTests checks the same bytes).

require_relative "rules_support"

# The story mapping of fixtures/story/classes.json as the DLL hands it to the scripts, see
# StoryTopicsTests.Classes_HandTheScriptsTheMappingsTable.
#
# @return [Hash] The table.
def classes_fixture_table
  story_table_hash(
    [[0, 22, 0], [23, 23, 64], [24, 30, 0], [31, 31, 65], [32, 2028, 0], [2029, 2029, 4], [2030, 7095, 0], [7096, 7096, 1], [7097, 7101, 0], [7102, 7102, 8]],
    [[0, 1000, 0], [1001, 1001, 3], [1002, 1051, 0], [1052, 1052, 1], [1053, 1061, 0], [1062, 1062, 1], [1063, 1140, 0], [1141, 1141, 3], [1142, 1353, 0],
     [1354, 1354, 17], [1355, 3004, 0], [3005, 3005, 35]],
    0,
    "rev" => 7,
    "self" => { "ce154.*" => 1, "ce20.A" => 0, "ss0.*.F" => 1, "ss12.5.A" => 8, "ss231.*.*" => 1, "ss231.4.*" => 0, "ss231.5.B" => 1, "ss40.*.C" => 0 },
    "index" => [7_000_039, 40_000_002],
    "local_steps" => [[1052, [3, 4, 5], 2, [[484, 30], [483, 0]]]],
    "gates" => { "1" => 25, "2" => 55 })
end

# Answers the story topics of the DLL on a FakeBridge: the staged ones kept in $story_staged as
# [topic, payload], story.take from $takes (oldest first), story.classes from $classes.
#
# @param fake [FakeBridge] The bridge.
def answer_story(fake)
  $story_staged = []
  $takes = []
  $classes = nil
  %w(story.enter story.close story.writes story.level story.seed story.tell story.watch).each do |topic|
    fake.answer(topic) do |payload|
      $story_staged << [topic, payload]
      nil
    end
  end
  fake.answer("story.take") { $takes.shift }
  fake.answer("story.classes") { $classes }
end

# Lists the payloads the scripts staged on a story topic.
#
# @param topic [String] The topic, such as "story.writes".
# @return [Array] The payloads, oldest first.
def staged(topic)
  $story_staged.select { |name, _| name == topic }.map { |_, payload| payload }
end

# Makes the status the DLL posts, see StoryTopics.StatusOf.
#
# @param fields [Hash] The fields that differ from a player placed on the world's track at revision 1.
# @return [Hash] The status.
def story_status(fields = {})
  { "synced" => true, "track" => "world", "part" => "1", "gate" => nil, "rev" => 1, "taken" => 0,
    "world" => { "rev" => 1, "part" => "1", "route" => "none", "done" => [], "checkpoints" => [] }, "pending" => false, "need_seed" => false,
    "classes" => 1, "tellings" => {}, "told" => {}, "telling" => nil, "holder" => nil, "unanswered" => 0 }.merge(fields)
end

# Makes a whole track as the DLL hands it in a take, see StoryTopics.TakeOf.
#
# @param keys [Hash{String => String}] The track's keys.
# @param fields [Hash] The state's fields that differ from the world's track in Part 1.
# @return [Hash] The take.
def track_take(keys, fields = {}, rev = 1)
  { "state" => { "why" => "sync", "track" => "world", "part" => "1", "gate" => nil, "move" => nil, "keys" => keys, "chests" => {}, "held" => [] }.merge(fields),
    "keys" => [], "rev" => rev }
end

# Makes a take of keys alone, as pushes and answers bring them.
#
# @param keys [Array<Array>] Each key and value.
# @param rev [Integer] The revision the take brings the game to.
# @return [Hash] The take.
def keys_take(keys, rev = 2)
  { "state" => nil, "keys" => keys, "rev" => rev }
end
