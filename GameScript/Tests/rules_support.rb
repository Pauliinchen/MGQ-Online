#----------------------------------------------------------------
#  rules_support.rb
#
#  Changelog:
#      Paulinchen  2026-11-08: Answered the installed mods the scripts hand over in place of the relay's mod catalog, and dropped the check the scripts no longer call
#      Paulinchen  2026-11-06: Answered the sorts each test sets and wrote the world's rules out instead of reading recorded cases
#      Paulinchen  2026-11-05: Answered the rewards a party member catches up with by the fields each test sets instead of from a stand-in of their constants
#                            - Dropped the reader of the relay's seed rows, which only the tables of the catch-up engine read
#                            - Answered the mods, squads, world rules, story parts and the World overview's title with the values each test sets instead of from their stand-ins
#                            - Answered the shared mod settings, the mods check and the frozen fights' write journal with the values each test sets instead of from their stand-ins
#                            - Answered the game data's fingerprint and the written messages as fake texts instead of as the DLL writes them
#                            - Answered the event sorter from the recorded cases alone, a resumed fight's page as each test sets it
#                            - Answered the worlds on this PC, the world screen's model and its forms with the values each test sets instead of from their stand-ins
#                            - Answered the topics of the story's telling with the values each test sets instead of from their stand-ins
#                            - Answered the raid bosses' rules from their stand-in
#                            - Answered the world entered with the values of its settings a test sets
#                            - Read the fields of a request a served battle's starter passed on by their kinds
#                            - Stood in for the DLL's topics of the world room, the directory's list and the development build, noting each call in $calls
#                            - Stood in for the one decision of the player's own common events, a resumed raid fight and whether a telling moves the world's story on, and named the castle's maps
#                            - Answered the topics of the one guard of the game's flow from its stand-in, checked against the reported cases
#      Paulinchen  2026-11-01: Dropped the stand-ins of the World overview's story topics and of marking settings shared, which no script calls
#      Paulinchen  2026-10-30: Dropped the stand-ins of the parking's topics
#                            - Dropped the stand-in of mods.install, which the Mod Framework does
#      Paulinchen  2026-10-28: Answered the chests, page flags and command index of a map's pages as a DLL without an events database
#                            - Took the fingerprint the events database is opened with and sorted the pages of a map handed over
#                            - Read the seed rows of the relay's story tables, from which the catch-up's tests build their tables
#                            - Answered the rewards a party member catches up with from the test's stand-in of coop_story_rewards.rbx
#      Paulinchen  2026-10-23: Dropped the stand-in of the directory's tickets, which no script asks for any more
#                            - Kept the test's one stand-in bridge in $world_bridge
#                            - Stood in for the frozen fights' write journal, checked against its golden cases
#                            - Answered the world screen's steps into a world with the steps a test sets
#                            - Answered the world screen's model
#                            - Answered the parking topics as for a game with no mod turned off
#                            - Answered the shared mod settings' topics with their golden texts and the steps a test queues
#                            - Answered the mods check, the directory's tickets and the mods topics the world screen calls
#                            - Answered the world screen's forms
#                            - Answered the worlds on this PC, the lists, the invite, the game data and the mod picker
#                            - Answered the World overview's story and title
#                            - Answered the mods text of a world
#                            - Kept the test's one stand-in bridge in $world_bridge
#      Paulinchen  2026-10-28: Answered the story's choices
#                            - Answered the calls of a story
#                            - Answered the story's scene
#                            - Answered the story's pages
#      Paulinchen  2026-10-23: Kept the test's one stand-in bridge in $world_bridge
#                            - Answered the event sorter
#                            - Answered the mod catalog a test sets
#                            - Added the answers to the world room's stand-in bridge when a test has one
#                            - Stood in for the squad math, checked against its golden cases
#                            - Answered the squad rules of a served battle and their defaults
#                            - Answered the ids coop.rbx makes up
#                            - Answered the story parts
#                            - Answered the world rules, squad rules and world codes
#                            - Answered the mod keys and the scripts in Patch
#                            - Created
#
#----------------------------------------------------------------

# The topics of the game's rules that left the scripts, answered on the test's one FakeBridge with
# the fixed values each test sets for its own case, or the world's rules every test shares. The C#
# tests own the rules; here the scripts are checked for what they ask and what they do with the
# answer.

require "json"
require_relative "bridge_support"

# Folder of the relay's seed rows of its story tables.
STORY_SEEDS = File.expand_path("../../Relay/seed/story", __dir__)

# The world's rules as the DLL answers world.rules: 2 to 32 seats, the game's difficulties and the
# squad's limits.
WORLD_RULES = {
  "seats" => { "min" => 2, "max" => 32, "default" => 4 },
  "difficulties" => [[-2, "VERY EASY"], [-1, "EASY"], [0, "NORMAL"], [1, "HARD"], [2, "VERY HARD"], [3, "HELL"], [4, "PARADOX"]],
  "difficulty" => 0,
  "formations" => [[0, "Original"], [4, "4"], [5, "5"], [6, "6"], [7, "7"], [8, "8"]],
  "fronts" => [1, 2, 3, 4],
  "squad" => { "luka" => false, "formation" => 4, "front" => 1, "raid_front" => 1 },
}.freeze

# Stands in for the DLL's answers of the rules' topics the scripts ask: the world's rules, the squads,
# the story's part, the World overview's title and the mods'.
class RuleAnswers
  include NotedRequests

  # The topics answered.
  TOPICS = %w(world.rules world.code squad.default squad.read squad.write squad.served squad.shares squad.rank squad.raid squad.arrange squad.past_cap
              story.part overview.title mods.keys mods.text mods.installed).freeze

  # What a topic answers while a test sets nothing: the recorded rules, else nothing.
  DEFAULTS = { "world.rules" => WORLD_RULES, "squad.default" => WORLD_RULES["squad"] }.freeze

  # @return [FakeBridge] The bridge answered on.
  attr_reader :fake

  # Answers the topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @fake = fake
    @asked = []
    @fixed = {}
    TOPICS.each { |topic| fake.answer(topic) { |request| answer(topic, request) } }
  end

  # Sets what a topic answers: a value, or a block that makes it of the request.
  #
  # @param topic [String] The topic.
  # @param value [Object] The answer, nil to answer as before the test set one.
  # @yieldparam request [Object] The request.
  def set(topic, value = nil, &block)
    block || !value.nil? ? @fixed[topic] = (block || value) : @fixed.delete(topic)
  end

  # Sets what a topic answers to each request a test names.
  #
  # @param topic [String] The topic.
  # @param answers [Hash] The answers by their requests, or by what the block makes of them; a
  #   request it lacks fails the test.
  # @yieldparam request [Object] The request.
  # @yieldreturn [Object] Its key in answers.
  def cases(topic, answers, &key)
    set(topic) do |request|
      found = key ? key.call(request) : request
      answers.fetch(found) { raise "no fixed answer of #{topic} for #{request.inspect}" }
    end
  end

  # Answers a topic: what the test set, else what DEFAULTS name.
  #
  # @param topic [String] The topic.
  # @param request [Object] The request.
  # @return [Object] The reply.
  def answer(topic, request)
    note(topic, request)
    return DEFAULTS[topic] unless @fixed.key?(topic)

    fixed = @fixed[topic]
    fixed.respond_to?(:call) ? fixed.call(request) : fixed
  end
end

# Makes up an id, its digits counted up instead of drawn, so a test can tell ids apart: exactly the
# length asked for, in the base asked for.
#
# @param request [Hash] "length" and "radix".
# @return [String] The id.
def counted_id(request)
  $random_ids = $random_ids.to_i + 1
  $random_ids.to_s(request["radix"] || 36).rjust(request["length"], "0")[-request["length"], request["length"]]
end

# The sorts the DLL answers, which a test sets for each list it hands over (see sorted_as), by the
# list's rows and, for a sort of one command, the command's index.
$sorts = {}

# The common events the DLL's decision answers as the player's own, which a test sets.
$own_commons = []

# What the DLL's decision answers for a resumed raid fight's page, which a test sets; nil answers
# the page's own sort.
$resumed_sort = nil

# The maps of the Pocket Castle's residents events.open answers, as PocketCastle in MGQOnline.Game
# names them.
CASTLE_MAPS = [227, 228, 229, 230] + (268..278).to_a

# Sets what the DLL answers when a list is sorted, or one of its commands.
#
# @param list [Array<RPG::EventCommand, Array>] The commands, or their rows as [code, indent, parameters].
# @param answer [Hash] The answer, as events.sort answers it.
# @param index [Integer, nil] The command a sort of one command names, nil for the whole list.
def sorted_as(list, answer, index = nil)
  rows = list.map { |command| command.is_a?(Array) ? command : [command.code, command.indent, command.parameters] }
  $sorts[[JSON.parse(JSON.generate(rows)), index]] = answer
end

# Answers the event sorter's topics as a DLL without an events database: events.open takes the
# fingerprint and answers that the database is missing, so the scripts hand every list over, whose
# sort a test sets (see sorted_as); the chests, the page flags and the command index of a map's
# pages answer none, and no telling moves the world's story on.
#
# @param fake [FakeBridge] The bridge.
def answer_events(fake)
  fake.answer("events.open") do |request|
    raise FakeBridge::BadRequest, "no fingerprint" unless request["fingerprint"].is_a?(String)

    { "usable" => false, "problem" => "no events database at Patch/Multiplayer/Data/events.db", "differing" => [], "castle_maps" => CASTLE_MAPS }
  end
  fake.answer("story.moves") { |_request| { "moves" => false, "progress" => [] } }
  fake.answer("events.sort") { |request| set_sort(request) }
  fake.answer("events.kinds") { |request| set_kinds(request) }
  fake.answer("events.chests") { |request| { "letters" => Array(request["rows"]).map { nil } } }
  fake.answer("events.pages") { |request| { "pages" => Array(request["rows"]).map { nil } } }
  fake.answer("events.index") { |request| { "indexes" => Array(request["pages"]).map { nil } } }
end

# Answers the sort of a map's pages: a page named by its length and shape as none, a page handed
# over as the kind its list was set to.
#
# @param request [Hash] The request.
# @return [Hash] The kinds.
def set_kinds(request)
  { "kinds" => Array(request["pages"]).map { |row| row[2].is_a?(Array) ? set_sort("list" => row[2])["list_kind"] : nil } }
end

# Answers one sort with what a test set for its list: a common event of $own_commons as the
# player's own, a resumed fight's page as $resumed_sort, and a list no test set fails the test.
#
# @param request [Hash] The request.
# @return [Hash] The answer, or unknown for a request that hands no list.
def set_sort(request)
  if !request["index"] && $own_commons.include?(request["common"])
    return { "kind" => "own", "list_kind" => "own", "may_tell" => false, "scene" => false, "marks" => [], "own" => "common event #{request['common']} is one of the game's own" }
  end
  return $resumed_sort if request["resumed"] && $resumed_sort
  return { "unknown" => true } unless request["list"]

  rows = JSON.parse(JSON.generate(request["list"]))
  $sorts.fetch([rows, request["index"]]) { raise "no sort set for #{rows.inspect} at #{request['index'].inspect}" }
end

# The rewards a party member catches up with as the DLL hands them (story.rewards, PartyRewards in
# the DLL), with none in them.
NO_PARTY_REWARDS = {
  "rev" => 1, "skills" => [], "actors" => [], "items" => {}, "sided" => { "skills" => [], "actors" => [] }, "route" => { "skills" => [], "actors" => [] },
  "final" => { "skills" => [], "actors" => [], "items" => [] }, "groups" => [], "chests" => [], "chest_flags" => [],
}.freeze

# Writes the rewards a party member catches up with as the DLL hands them.
#
# @param fields [Hash] The fields that differ from NO_PARTY_REWARDS.
# @return [Hash] The answer of story.rewards.
def party_rewards(fields = {})
  NO_PARTY_REWARDS.merge(fields)
end

# Answers the rewards a party member catches up with by the fields a test sets, and a Classic
# world's fetch of the story mapping, which answers nothing.
#
# @param fake [FakeBridge] The bridge.
# @param fields [Hash] The fields that differ from NO_PARTY_REWARDS.
def answer_party_rewards(fake, fields = {})
  fake.answer("story.rewards") { |_known| party_rewards(fields) }
  fake.answer("story.mapping") { |_world| nil }
end

# Has the scripts read the rewards a party member catches up with anew, as after a test put its
# stand-in of their table in place.
def rewards_changed
  MGQ_MpStoryState.instance_variable_set(:@rewards, nil)
  MGQ_MpStoryState.instance_variable_set(:@rewards_at, nil)
end

# The frozen fights' write journal as a fake: every write handed is kept as it came, and
# freeze.since answers each write after the mark in the order it came, with none of the DLL's
# journal's rules (which writes it drops, which value of a key written twice it keeps); a test
# answers freeze.since itself for a case whose rows those rules decide.
class FakeJournal
  # Answers the journal's topics on a bridge.
  #
  # @param fake [FakeBridge] The bridge.
  def initialize(fake)
    @writes = []
    fake.answer("freeze.journal") { |request| @writes.concat(Array(request["entries"])) && nil }
    fake.answer("freeze.since") { |mark| written_since(mark) }
  end

  private

  # Lists the writes handed after a mark.
  #
  # @param mark [Integer] The mark.
  # @return [Hash] "rows" (each [kind, key, before]) and "overflow".
  def written_since(mark)
    { "rows" => @writes.select { |seq, *_| seq > mark }.map { |_seq, kind, key, before| [kind, key, before] }, "overflow" => false }
  end
end

# Answers the frozen fights' write journal with a FakeJournal of its own.
#
# @param fake [FakeBridge] The bridge.
# @return [FakeJournal] The journal.
def answer_journal(fake)
  FakeJournal.new(fake)
end

# The mods the battle server runs as mods.served answers them, the mods mods.report names, the
# options mods.options was handed and the installed mods mods.framework was handed last.
$served_mods = []
$reported_mods = []
$sent_options = []
$framework_mods = nil

# Answers the mods topics the world screen and the world's mods call from what a test sets.
#
# @param fake [FakeBridge] The bridge.
def answer_mod_check(fake)
  fake.answer("mods.forget") { nil }
  fake.answer("mods.framework") { |request| $framework_mods = request; nil }
  fake.answer("mods.served") { |_mods| $served_mods }
  fake.answer("mods.report") { $reported_mods }
  fake.answer("mods.options") { |request| $sent_options << request; true }
end

# Each settings topic called, as [topic, request], and the steps the next calls answer, one Array
# of steps per call, which a test queues.
$settings_calls = []
$settings_steps = []

# What the shared mod settings' topics answer, which a test sets: whether settings are shared
# (settings.shared), the details' text (settings.details) and the world entered as the DLL
# describes it (settings.enter), nil for none.
$settings_shared = false
$settings_details = ""
$settings_world = nil

# Answers the shared mod settings' topics with the values a test set and the steps it queued,
# noting each call in $settings_calls.
#
# @param fake [FakeBridge] The bridge.
def answer_settings(fake)
  world = nil
  reply = lambda { |topic, request| $settings_calls << [topic, request]; { "world" => world, "steps" => $settings_steps.shift || [] } }
  fake.answer("settings.shared") { |_text| $settings_shared }
  fake.answer("settings.details") { |request| $settings_calls << ["settings.details", request]; $settings_details }
  fake.answer("settings.enter") { |request| world = $settings_world; reply.call("settings.enter", request) }
  fake.answer("settings.forget") { |request| world = nil; reply.call("settings.forget", request) }
  %w(settings.options settings.loaded settings.want settings.step settings.applied settings.live settings.observe settings.mods).each do |topic|
    fake.answer(topic) { |request| reply.call(topic, request) }
  end
  fake.answer("settings.told") { |request| $settings_calls << ["settings.told", request]; nil }
  fake.answer("settings.leave") { |seat| $settings_calls << ["settings.leave", seat]; nil }
end

# The world screen's calls of its steps into a world (WorldEntering in C#), each as [topic, request].
$screen_calls = []

# The steps the world screen's next call of a step topic gets, which a test sets; every call takes
# them and leaves none.
$screen_steps = []

# Whether the DLL's steps wait for the list to enter a world, as screen.do answers it.
$screen_waiting = false

# Answers the topics of the world screen's steps with the steps a test set, since their rules have
# their tests in C# (WorldEnteringTests); the script tests check that the screen plays the steps it
# is handed and hands back what the player did.
#
# @param fake [FakeBridge] The bridge.
def answer_screen_steps(fake)
  %w(screen.enter screen.answer screen.step screen.do).each do |topic|
    fake.answer(topic) do |request|
      $screen_calls << [topic, request]
      steps = $screen_steps
      $screen_steps = []
      topic == "screen.do" ? { "steps" => steps, "waiting" => $screen_waiting } : { "steps" => steps }
    end
  end
end

# Finds the requests of the world screen's calls of a step topic.
#
# @param topic [String] The topic, such as "screen.answer".
# @return [Array<Hash>] Each call's request, oldest first.
def screen_requests(topic)
  $screen_calls.select { |called, _| called == topic }.map { |_, request| request }
end

# A world of the directory's list as the DLL hands it (topic directory.list, ScreenTopics.ListedValue
# in C#), every field the test does not name at the list's default.
#
# @param id [String] The world's id.
# @param name [String] Its name.
# @param fields [Hash] The fields that differ, by name.
# @return [Hash] The world.
def listed_value(id, name, fields = {})
  { "id" => id, "seats" => 4, "online" => 0, "creator_id" => "c", "active" => 0, "creator_name" => "C", "name" => name, "start" => "none",
    "members" => [], "hidden" => false, "choose" => false, "open" => false, "featured" => false, "strict" => false, "data" => "", "mods" => "",
    "description" => "", "mod_hashes" => "", "settings" => "", "type" => "classic", "share" => "off", "difficulty" => nil, "other_mods_off" => false,
    "squad" => nil, "raid_bosses" => false, "mods_unread" => false }.merge(fields)
end

# The directory's list as the DLL hands it (topic directory.list).
#
# @param worlds [Array<Hash>] The worlds, see listed_value.
# @param state [String] How the list stands.
# @return [Hash] The list.
def directory_list(worlds, state = "ready")
  { "state" => state, "error" => nil, "admin" => false, "worlds" => worlds }
end

# The requests of the DLL's topics of a Raid World's shared companions, whose state marks them
# busy once they start, as the DLL's does.
RAID_STORY_KINDS = { "raid.story.fetch" => "fetch", "raid.companions.add" => "companions" }

# What every fake text the DLL writes in the tests starts with, which no game writes.
FAKE_TEXT = "fake:"

# Writes a message as the fake DLL writes it (message.write): its fields and body as JSON behind
# FAKE_TEXT. The C# tests own how the DLL writes a message.
#
# @param fields [Hash] The fields.
# @param body [String] The body.
# @return [String] The text.
def fake_message(fields, body = "")
  FAKE_TEXT + JSON.generate([fields, body.to_s])
end

# Answers the DLL's topics of the player's id, the directory's list ($directory), the world room's
# opening and closing, the development build ($dev_build), the game data's fingerprint as a fake
# text of the ids measured, writing a message as fake_message and reading a request's fields as the
# texts they came as, the ids coop.rbx makes up (counted_id), and a Raid World's shared companions
# ($raid_story, the state), noting each call but the reads in $calls as [topic, request].
#
# @param fake [FakeBridge] The bridge.
def answer_dll(fake)
  fake.answer("world.player_id") { $player_id || "me" }
  fake.answer("directory.list") { $directory || directory_list([], "idle") }
  fake.answer("raid.story.state") { $raid_story || {} }
  fake.answer("worlds.fingerprint") { |parts| FAKE_TEXT + JSON.generate(parts) }
  fake.answer("message.write") { |request| fake_message(request["fields"], request["body"]) }
  fake.answer("message.read_pairs") { |pairs| Hash[pairs] }
  fake.answer("id.random") { |request| counted_id(request) }
  %w(directory.open world.open world.close update.dev_build raid.story.fetch raid.companions.add raid.pools.fetch).each do |topic|
    fake.answer(topic) do |request|
      ($calls ||= []) << [topic, request]
      kind = RAID_STORY_KINDS[topic]
      ($raid_story ||= {})[kind] = "busy" if kind
      topic == "update.dev_build" ? $dev_build == true : !%w(directory.open world.close).include?(topic)
    end
  end
end

# Opens the scripts' bridge on the test's one FakeBridge, $world_bridge, made here unless the world
# room's or the interface's stand-ins made it, with the fixed answers of the rules' topics; those of
# RuleAnswers are kept in $rule_answers.
#
# @return [FakeBridge] The bridge, for a test to add answers or read the calls.
def open_rules_bridge
  load_bridge unless defined?(MGQ_Multiplayer::Bridge)
  fake = ($world_bridge ||= FakeBridge.new)
  answer_dll(fake)
  $rule_answers = RuleAnswers.new(fake) unless $rule_answers && $rule_answers.fake.equal?(fake)
  answer_mod_check(fake)
  answer_settings(fake)
  answer_events(fake)
  answer_local_worlds(fake)
  answer_screen(fake)
  answer_forms(fake)
  answer_screen_steps(fake)
  answer_telling(fake)
  answer_journal(fake)
  answer_party_rewards(fake)
  answer_raid_rules(fake)
  MGQ_Multiplayer::Bridge.open(fake)
  fake
end

require_relative "telling_support"
require_relative "local_worlds_support"
require_relative "screen_support"
require_relative "form_support"
require_relative "raid_support"
