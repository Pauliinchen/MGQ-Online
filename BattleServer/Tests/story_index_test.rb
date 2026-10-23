#----------------------------------------------------------------
#  story_index_test.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Tests the story mapping's index the server derives for the relay (story_index.rb): without MGQ
# Online's C# core it says it cannot, with it it hands the core the rows' fields the index reads and
# answers the rows' revision with the core's index and names.

require_relative "support"
load_mgq_bridge
require_relative File.join(LIB_DIR, "story_index")

bridge = MGQ_Multiplayer::Bridge
request = {
  "rowsRev" => 7,
  "keys" => [{ "key" => "v1001", "kind" => "one_way", "note" => "story" }],
  "events" => [{ "key" => "ss231.*.*", "share" => "personal", "chest" => false }],
}

check("without the core the server says it cannot derive the index", StoryIndex.answer(request)[:ok], false)
check("a request without the rows' revision is refused", StoryIndex.answer(request.merge("rowsRev" => "7"))[:ok], false)

# The core as the bridge reaches it: it answers story.index with $core_answer, or raises $core_error.
asked = []
bridge.define_singleton_method(:has?) { |topic| topic == StoryIndex::TOPIC }
bridge.define_singleton_method(:call!) do |topic, rows|
  asked << [topic, rows]
  raise MGQ_Multiplayer::Bridge::Error, $core_error if $core_error

  $core_answer
end
$core_answer = { "events" => [[12, 3]], "commons" => [40], "names" => { "switches" => { 60 => "Met Alice" }, "companions" => 1 } }

check("with the core it answers the rows' revision with the core's index and names",
      StoryIndex.answer(request),
      { ok: true, built: 7, events: [[12, 3]], commons: [40], names: { "switches" => { 60 => "Met Alice" }, "companions" => 1 } })
check("handing the core only the fields the index reads",
      asked, [["story.index", { "keys" => [{ "key" => "v1001", "kind" => "one_way" }], "events" => [{ "key" => "ss231.*.*", "share" => "personal" }] }]])
$core_error = "story.index answered bad_request: each row names its key"
check("and a refusal of the core as why not", StoryIndex.answer(request), { ok: false, error: $core_error })
