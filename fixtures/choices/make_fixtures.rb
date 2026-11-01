#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-31: Read the old scripts from a commit that feat/refactor holds
#                            - Wrote the texts C# words anew as C# words them
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Writes cases.json next to this file: the golden cases of the story's choices, recorded from
# coop_choices.rbx as it was before its table and rules moved to C# (MGQOnline.Game's
# Story/Choices). "table" holds the script's constants; "cases" hold each rule's answer in the shape
# of the bridge topic that answers it now (ChoiceTopics), the request as the script builds it and
# the reply the old rule gave. MGQOnline.Game.Tests replays every case, and the script tests'
# stand-in (GameScript/Tests/choices_support.rb) is checked against them. The script no longer holds
# those rules, so hand it the script of commit 40f11e4d, which still kept them, to write the cases
# again, on Ruby 3.3 (the table of the branch events and the replies on them have since been
# rewritten from what C# answers with the outcomes the walk of the game's data found, which a new
# recording would undo):
#
#   git show 40f11e4d:GameScript/Multiplayer/Scripts/coop_choices.rbx > old_choices.rbx
#   ruby fixtures/choices/make_fixtures.rb old_choices.rbx

require "json"

# The game's state the old rules read through the stand-ins below, set by each case.
$state = {}

# The log, which the cases leave out.
module MGQ_MpLog; def log(_line); end; end
# The actions' colors and offers.
module MGQ_MpActions; LINE_COLOR = nil; def self.offer(_adapter); end; end
# The world screen's form window and the menu scenes the screen builds on.
class Window_MpWorldForm; end
class Scene_MenuBase; end
# The game's frame counter.
module Graphics; def self.frame_count; $state[:now].to_i; end; end
# The party: a Raid World or not, the party's leader and its members.
module MGQ_MpCoop
  # Takes no routes.
  def self.route(*); end
  # The player leads the party.
  def self.party_leader; :me; end
  # The party or the map.
  module Scope; def self.raid?; $state[:raid] ? true : false; end; end
  # The party's members.
  module Party; def self.members; $state[:members] || []; end; end
end
# The world's players and the player.
module MGQ_MpOverworldSync
  # Takes no state fields or ticks.
  def self.state_fields(*); end
  def self.on_tick(*); end
  # The player.
  module Me; def self.id; "me"; end; end
end
# The story state: the game's values are plain arrays here.
module MGQ_MpStoryState
  # Answers the values as they are.
  def self.data_of(values); values; end
  # The player's companions.
  def self.roster_ids; $state[:roster] || []; end
end
# The party's story: the player's own story and how far stories are.
module MGQ_MpCoopStory
  # The player's own story, its switches and variables.
  def self.own_story_data; $state[:own]; end
  # Whether the player plays the leader's story.
  def self.guest?; $state[:guest] ? true : false; end
  # Reads how far a story is from its text.
  def self.read_markers(text); values = text.to_s.split(","); values.size == 4 ? values.map(&:to_i) : nil; end
  # How far the player's own story is.
  def self.own_markers; $state[:markers]; end
end
# The world's story: the routes the world may still take at the Great Decision.
module MGQ_MpWorldStory; def self.decision_routes; $state[:world_routes]; end; end
# A player as the party knows them.
Peer = Struct.new(:state)

load(ARGV[0] || abort("Name the coop_choices.rbx of commit 40f11e4d, see the header."))
CHOICES = MGQ_MpCoopChoices

# The switches, variables and companions the rules read, in the order the requests name them.
READS = { "s" => [4, 5, 2090, 2096, 2097, 2148, 2149, 2210, 2211, 2212, 2213, 2280, 2281, 7096, 7097], "v" => [912, 1001, 1050, 1051, 1061], "roster" => [153, 163, 167] }

# Makes a story's values as arrays the rules index.
#
# @param on [Array<Integer>] The switches on.
# @param variables [Hash{Integer => Integer}] The variables set.
# @return [Array<Array>] The switches and the variables.
def story(on, variables)
  switches = []
  values = []
  on.each { |id| switches[id] = true }
  variables.each { |id, value| values[id] = value }
  [switches, values]
end

# Writes a story's values as the requests hand them over: the switches read that are on, each
# variable read with its value, and the companions read that are in the roster.
#
# @param on [Array<Integer>] The switches on.
# @param variables [Hash{Integer => Integer}] The variables set.
# @param roster [Array<Integer>] The companions.
# @return [Hash] The values.
def values(on, variables = {}, roster = [])
  { "s" => READS["s"] & on, "v" => READS["v"].map { |id| [id, variables[id].to_i] }, "roster" => READS["roster"] & roster }
end

# Sets the game's state for the next rule and writes the context the requests hand over.
#
# @param options [Hash] :s (switches on), :v (variables), :roster, :raid, :ends ([ed1, ed2]),
#   :raid_route and :world_routes.
# @return [Hash] The context.
def game(options = {})
  $state = options
  $game_switches, $game_variables = story(options[:s] || [], options[:v] || {})
  $game_system_switches = { :ed1 => (options[:ends] || [])[0], :ed2 => (options[:ends] || [])[1] }
  CHOICES.instance_variable_set(:@raid_route, options[:raid_route])
  { "raid" => options[:raid] ? true : false, "values" => values(options[:s] || [], options[:v] || {}, options[:roster] || []),
    "ends" => [(options[:ends] || [])[0] ? true : false, (options[:ends] || [])[1] ? true : false],
    "raid_route" => options[:raid_route], "world_routes" => options[:world_routes] }
end

# Writes switches or variables by id as the topics hand them: [id, value] pairs.
#
# @param values [Hash, nil] The values by id.
# @return [Array<Array>] The pairs.
def pairs(values)
  (values || {}).map { |id, value| [id, value] }
end

# Writes an outcome as the table holds it.
#
# @param outcome [Hash] The outcome.
# @return [Hash] The outcome with plain keys.
def outcome_entry(outcome)
  entry = {}
  outcome.each do |name, value|
    entry[name.to_s] = [:switches, :variables, :least].include?(name) ? pairs(value) : value
  end
  entry
end

# The cases, in the order written.
CASES = []

# The answers C# words anew, each the script's wording and the one C# gives (StoryChoices).
REWORDED = [[/'s game tells no story progress\.\z/, "'s story is not known yet."]]

# Records a case.
#
# @param topic [String] The topic.
# @param request [Object] The request.
# @param reply [Object] The old rule's answer.
def record(topic, request, reply)
  reply = REWORDED.inject(reply) { |text, (old, now)| text.sub(old, now) } if reply.is_a?(String)
  CASES << { "topic" => topic, "request" => request, "reply" => reply }
end

# Records which choices a catch-up carries a player past.
#
# @param from [Integer] The progress before.
# @param to [Integer] The progress after.
# @param on [Array<Integer>] The switches on.
# @param variables [Hash] The variables.
# @param roster [Array<Integer>] The companions.
def passed(from, to, on = [], variables = {}, roster = [])
  switches, values_by_id = story(on, variables)
  record("choices.passed", { "from" => from, "to" => to, "values" => values(on, variables, roster) },
         CHOICES.passed(from, to, switches, values_by_id, roster).map { |key| key.to_s })
end

# Each choice at its point: one before is not passed, the point itself is, a start at it is not.
CHOICES::BRANCHES.each do |branch|
  passed(branch.point - 1, branch.point)
  passed(branch.point - 2, branch.point - 1)
  passed(branch.point, branch.point + 1)
end
passed(5, 40)
# Each choice made by the switches, variables or companions its rule reads, and those that do not
# make it yet.
passed(0, 40, [4])
passed(0, 40, [5])
passed(0, 40, [2096])
passed(0, 40, [2097])
passed(0, 40, [], 1050 => 9)
passed(0, 40, [], 1050 => 8)
passed(0, 40, [], 1051 => 5)
passed(0, 40, [], 1051 => 4)
passed(0, 40, [], 1061 => 1)
passed(0, 40, [2213])
passed(0, 40, [7007, 7008])
passed(0, 40, [2281])
passed(0, 40, [2090])
passed(0, 40, [], {}, [153])
passed(0, 41, [], 1001 => 40)

# Records the choices a story passing on asks the player's own outcome of.
#
# @param from [Integer] The progress before.
# @param to [Integer] The progress after.
# @param options [Hash] :changed, :raid, :s, :v, :roster and :waiting.
def prompts(from, to, options = {})
  switches, values_by_id = story(options[:s] || [], options[:v] || {})
  $state = { :raid => options[:raid], :own => [switches, values_by_id], :roster => options[:roster] || [] }
  waiting = options[:waiting] || []
  CHOICES.instance_variable_set(:@prompts, waiting.dup)
  CHOICES.instance_variable_set(:@accepted, nil)
  CHOICES.story_passed(from, to, options[:changed] || [])
  record("choices.prompts",
         { "from" => from, "to" => to, "changed" => options[:changed] || [], "raid" => options[:raid] ? true : false,
           "values" => values(options[:s] || [], options[:v] || {}, options[:roster] || []), "waiting" => waiting.map { |key| key.to_s } },
         (CHOICES.instance_variable_get(:@prompts) - waiting).map { |key| key.to_s })
end

prompts(15, 17)
prompts(5, 40)
prompts(5, 40, :raid => true)
prompts(15, 16, :changed => [2280])
prompts(15, 16, :changed => [2280], :s => [2281])
prompts(15, 16, :changed => [4, 1001])
prompts(15, 16, :changed => [1065])
prompts(15, 17, :waiting => [:magistea])
prompts(15, 17, :waiting => [:spider])
prompts(15, 32, :s => [2097], :v => { 1061 => 2 }, :roster => [153])

# Records the choices a later build added that a Raid World's story is past without the save's
# own outcome.
#
# @param progress [Integer] The world's progress.
# @param options [Hash] :raid, :s, :v and :waiting.
def missed(progress, options = {})
  context = game(:raid => options.fetch(:raid, true), :s => options[:s], :v => options[:v])
  waiting = options[:waiting] || []
  CHOICES.instance_variable_set(:@prompts, waiting.dup)
  CHOICES.missed(progress)
  record("choices.missed", { "progress" => progress, "raid" => context["raid"], "values" => context["values"], "waiting" => waiting.map { |key| key.to_s } },
         (CHOICES.instance_variable_get(:@prompts) - waiting).map { |key| key.to_s })
end

missed(22)
missed(21)
missed(30, :v => { 1051 => 5 })
missed(30, :raid => false)
missed(30, :waiting => [:navy])

# Records the outcomes the screen offers for a choice.
#
# @param key [Symbol] The choice.
# @param options [Hash] The game's state, see game.
def offered(key, options = {})
  request = game(options).merge("key" => key.to_s)
  outcomes =
    case key
    when :navy then CHOICES.navy_sides
    when :decision then CHOICES.raid? ? CHOICES.decision_routes : (0...CHOICES.labels(key).size).to_a
    else (0...CHOICES.labels(key).size).to_a
    end
  record("choices.offered", request, { "labels" => CHOICES.labels(key), "outcomes" => outcomes })
end

offered(:side)
offered(:decision)
offered(:decision, :ends => [true, true])
offered(:decision, :ends => [true, false])
offered(:decision, :raid => true)
offered(:decision, :raid => true, :s => [7096, 7097])
offered(:decision, :raid => true, :s => [7096])
offered(:decision, :raid => true, :ends => [true, true])
offered(:decision, :raid => true, :world_routes => [1, 2])
offered(:decision, :raid => true, :raid_route => 2, :world_routes => [0, 1])
offered(:navy)
offered(:navy, :s => [2149])
offered(:navy, :s => [2148, 2149])

# Records whether the player cleared both endings, as the third way of the Great Decision asks.
#
# @param options [Hash] The game's state, see game.
def endings(options)
  record("choices.endings", game(options), CHOICES.both_endings?)
end

endings(:ends => [true, true])
endings(:ends => [true, false])
endings(:raid => true, :s => [7096, 7097])
endings(:raid => true, :s => [7097], :ends => [true, true])

# Records the line of what an outcome brings.
#
# @param key [Symbol] The choice.
# @param index [Integer] The answer.
# @param answers [Hash{Symbol => Integer}] The answers given so far.
# @param route [Integer, nil] The leader's route.
# @param options [Hash] The game's state, see game.
def note(key, index, answers = {}, route = nil, options = {})
  request = game(options).merge("key" => key.to_s, "index" => index, "answers" => Hash[answers.map { |name, value| [name.to_s, value] }], "route" => route, "leader" => "Lead")
  record("choices.note", request, CHOICES.note(key, index, answers, route, "Lead"))
end

note(:side, 1)
note(:sphinx, 0)
note(:navy, 0)
note(:navy, 0, {}, nil, :s => [2149])
note(:succubus, 0, :magistea => 1)
note(:succubus, 0, :magistea => 0)
note(:succubus, 1, :magistea => 0)
note(:succubus, 1, :magistea => 1)
note(:succubus, 0, {}, nil, :roster => [163])
note(:succubus, 1, {}, nil, :s => [2096])
note(:succubus, 1)
note(:decision, 1, {}, 1)
note(:decision, 0, {}, 1)
note(:decision, 0)
note(:decision, 2, {}, 2)
note(:decision, 1, {}, 0, :v => { 912 => 1 })
note(:decision, 0, {}, nil, :raid => true, :raid_route => 2)
note(:decision, 1, {}, nil, :raid => true, :world_routes => [0, 1])

# Records what an outcome sets and brings.
#
# @param key [Symbol] The choice.
# @param index [Integer] The answer.
# @param answers [Hash{Symbol => Integer}] The answers given so far.
# @param options [Hash] The game's state, see game.
def outcome(key, index, answers = {}, options = {})
  request = game(options).merge("key" => key.to_s, "index" => index, "answers" => Hash[answers.map { |name, value| [name.to_s, value] }])
  if key == :side
    reply = { "side" => index == 0 ? "alice" : "ilias" }
  else
    chosen = key == :succubus ? CHOICES.succubus_outcome(index, answers) : CHOICES.branch(key).outcomes[CHOICES.outcome_index(key, index)]
    reply = { "title" => CHOICES.branch(key).title, "label" => CHOICES.labels(key)[index], "switches" => pairs(chosen[:switches]),
              "variables" => pairs(chosen[:variables]), "least" => pairs(chosen[:least]), "self_switches" => chosen[:self_switches] || [],
              "joins" => chosen[:joins] || [], "ship" => chosen[:ship] }
  end
  record("choices.outcome", request, reply)
end

outcome(:side, 0)
outcome(:side, 1)
outcome(:magistea, 0)
outcome(:magistea, 1)
outcome(:navy, 0)
outcome(:navy, 1)
outcome(:navy, 0, {}, :s => [2149])
outcome(:plansect, 1)
outcome(:spider, 1)
outcome(:sphinx, 0)
outcome(:sphinx, 1)
outcome(:succubus, 0, :magistea => 1)
outcome(:succubus, 0, :magistea => 0)
outcome(:succubus, 1, :magistea => 0)
outcome(:succubus, 1, {}, :roster => [167])
outcome(:succubus, 1, {}, :s => [2097])

# Records the switches, variables and self switches that are the player's own as choices'
# outcomes.
#
# @param raid [Boolean] Whether a Raid World is open.
# @param own [Array, nil] The switches on and the variables of the player's own story, nil for none.
# @param guest [Boolean] Whether the player plays the leader's story.
def personal(raid, own, guest = true)
  $state = { :raid => raid, :guest => guest, :own => own && story(own[0], own[1]) }
  CHOICES.instance_variable_set(:@own_keys, nil)
  keys = raid ? CHOICES.raid_keys : (guest ? CHOICES.own_keys : [{}, {}])
  maps = raid ? CHOICES::NAVY_MAPS : []
  record("choices.personal", { "raid" => raid, "own" => !raid && guest && own ? values(own[0], own[1]) : nil },
         { "s" => keys[0].keys, "v" => keys[1].keys, "maps" => maps, "self_switches" => raid ? CHOICES::NAVY_SELF_SWITCHES : [] })
  check_personal(keys, maps)
end

# Checks the keys recorded against the old rules asked one by one.
#
# @param keys [Array<Hash>] The switches and variables recorded.
# @param maps [Array<Integer>] The maps recorded.
def check_personal(keys, maps)
  (0..8000).each do |id|
    raise "personal? differs at s#{id}" unless CHOICES.personal?(:s, id) == keys[0].key?(id)
    raise "personal? differs at v#{id}" unless CHOICES.personal?(:v, id) == keys[1].key?(id)
  end
  raise "personal_self_switch? differs" unless CHOICES.personal_self_switch?([maps.first || 709, 1, "A"]) == !maps.empty?
end

personal(true, nil)
personal(false, [[2096, 2281], { 1061 => 1 }])
personal(false, [[], {}])
personal(false, [[4, 2090], { 1001 => 40 }])
personal(false, [[2096], {}], false)

# Records why the catch-up leaves out a reward.
#
# @param kind [Symbol] The reward's kind.
# @param id [Integer, String] The reward.
def skip(kind, id)
  CHOICES.instance_variable_set(:@accepted, nil)
  record("choices.skip", { "kind" => kind.to_s, "id" => id }, CHOICES.skip_reason(kind, id))
end

skip(:actors, 163)
skip(:actors, 204)
skip(:actors, 5)
skip(:actors, 540)
skip(:items, 163)

# Records why a leader may not offer a member to sync their story.
#
# @param theirs [String] How far the member's story is, as their state tells it.
# @param own [Array<Integer>] How far the player's is.
# @param follows [Boolean] Whether the member follows the player's story.
def refusal(theirs, own, follows = false)
  $state = { :markers => own }
  peer = Peer.new({ "name" => "Mem", "sm" => theirs, "ssync" => follows ? "me" : "" })
  record("choices.offer_refusal", { "name" => "Mem", "theirs" => MGQ_MpCoopStory.read_markers(theirs), "own" => own, "follows" => follows },
         CHOICES.offer_refusal(peer))
end

refusal("", [30, 0, 0, 0])
refusal("20,0,0,0", [30, 0, 0, 0], true)
refusal("30,0,0,0", [30, 0, 0, 0])
refusal("20,0,1,0", [30, 0, 0, 0])
refusal("20,0,0,0", [30, 0, 0, 0])
refusal("40,0,0,0", [40, 1, 0, 0])

# Records which of the player's offers ran out by a frame.
#
# @param now [Integer] The frame.
# @param since [Array<Array>] Each offer's member and its start frame.
def lapsed(now, since)
  members = since.map { |id, _| Peer.new({ "id" => id, "ssync" => "" }) }
  $state = { :now => now, :members => members }
  offers = {}
  since.each { |id, start| offers[id] = { :nonce => 1, :since => start, :name => id } }
  CHOICES.instance_variable_set(:@offers, offers)
  CHOICES.tick_offers
  record("choices.lapsed", { "now" => now, "since" => since }, since.map { |id, _| id } - CHOICES.instance_variable_get(:@offers).keys)
end

lapsed(3699, [["a", 100]])
lapsed(3700, [["a", 100], ["b", 200]])
lapsed(50, [["a", 100]])

# The table as the script held it.
table = {
  "branches" => CHOICES::BRANCHES.map do |branch|
    { "key" => branch.key.to_s, "title" => branch.title, "point" => branch.point, "hint" => branch.hint, "outcomes" => branch.outcomes.map { |outcome| outcome_entry(outcome) } }
  end,
  "succubus" => CHOICES::SUCCUBUS.map { |(side, with), outcome| { "side" => side, "with" => with, "switches" => pairs(outcome[:switches]), "joins" => outcome[:joins] } },
  "succubus_switches" => CHOICES::SUCCUBUS_SWITCHES,
  "choice_companions" => CHOICES::CHOICE_COMPANIONS,
  "later_branches" => CHOICES::LATER_BRANCHES.map { |key| key.to_s },
  "navy_sides" => CHOICES::NAVY_SIDES,
  "navy_maps" => CHOICES::NAVY_MAPS,
  "navy_self_switches" => CHOICES::NAVY_SELF_SWITCHES,
  "great_decision" => CHOICES::GREAT_DECISION,
  "routes" => CHOICES::ROUTES,
  "chaos_start" => CHOICES::CHAOS_START,
  "route_clears" => CHOICES::ROUTE_CLEARS,
  "offer_frames" => CHOICES::OFFER_FRAMES,
  "reads" => READS,
}

# What the scripts read of the table through choices.table.
decision = CHOICES.branch(:decision).outcomes.map { |entry| entry[:return] ? { "side" => entry[:side], "return" => entry[:return], "map" => entry[:map] } : {} }
record("choices.table", nil,
       { "branches" => CHOICES::BRANCHES.map { |branch| [branch.key.to_s, branch.title, branch.point, branch.hint] }, "reads" => READS,
         "great_decision" => CHOICES::GREAT_DECISION, "routes" => CHOICES::ROUTES, "chaos_start" => CHOICES::CHAOS_START, "decision" => decision,
         "offer_frames" => CHOICES::OFFER_FRAMES })

lines = CASES.map { |entry| "    " + JSON.generate(entry) }
text = "{\n  \"source\": \"coop_choices.rbx at 40f11e4d, Ruby #{RUBY_VERSION}\",\n  \"table\": #{JSON.generate(table)},\n  \"cases\": [\n#{lines.join(",\n")}\n  ]\n}\n"
File.write(File.join(__dir__, "cases.json"), text)
puts "wrote #{CASES.size} cases"
