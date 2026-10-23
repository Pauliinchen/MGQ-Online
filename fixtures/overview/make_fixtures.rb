#----------------------------------------------------------------
#  make_fixtures.rb
#
#  Changelog:
#      Paulinchen  2026-10-23: Created
#
#----------------------------------------------------------------

# Writes story.json: how world_overview.rbx wrote a player's and the world's place in the story and
# the World overview's title before those texts moved to OverviewText in MGQOnline.Game, as golden
# cases both sides check. It runs the script's own methods over stand-ins with the translated
# game's variable and switch names.
#
#   ruby fixtures/overview/make_fixtures.rb <world_overview.rbx of the version to record>

require "json"

source = File.read(ARGV[0] || File.expand_path("../../GameScript/Multiplayer/Scripts/world_overview.rbx", __dir__), :encoding => "UTF-8")

# The translated game's names of the variables and switches the story is read from.
VARIABLE_NAMES = { 1001 => "Overall Events Progress", 1141 => "天界ルート進行度", 1142 => "魔界ルート進行度", 1143 => "混沌ルート進行度" }
SWITCH_NAMES = { 4 => "Alice Chosen", 5 => "Ilias Chosen" }

# The difficulties' names as world.rules hands them out, from -2 on.
DIFFICULTY_NAMES = JSON.parse(File.read(File.expand_path("../world/rules.json", __dir__)))["rules"]["difficulties"]

# Stands in for the game's database of names.
class RecordedSystem
  attr_reader :variables, :switches

  def initialize
    @variables = Array.new(1200)
    @switches = Array.new(10)
    VARIABLE_NAMES.each { |id, name| @variables[id] = name }
    SWITCH_NAMES.each { |id, name| @switches[id] = name }
  end
end

# Stands in for the world's story as world_story.rbx reads it: the part as the relay counts it.
module MGQ_MpWorldStory
  ROUTES = %w(ad mr chaos)
  ROUTE_VARIABLES = [1141, 1142, 1143]
  DECISION_PART = "3"

  class << self
    attr_accessor :world
  end

  def self.part_of(counters)
    routes = ROUTE_VARIABLES.map { |id| counters["r#{id}"].to_i }
    index = routes.index { |value| value > 0 }
    return ROUTES[index] if index

    progress = counters["p"].to_i
    progress < 19 ? "1" : progress < 34 ? "2" : "3"
  end
end

# Stands in for the open world.
module MGQ_MpWorld
  def self.difficulty_name(value)
    found = DIFFICULTY_NAMES.find { |entry| entry[0] == value }
    found && found[1]
  end
end

# Stands in for the world's difficulty.
module MGQ_MpWorldDifficulty
  class << self
    attr_accessor :value
  end
end

# Stands in for whether the open world is a Raid World.
module MGQ_MpCoop
  module Scope
    class << self
      attr_accessor :raid
    end

    def self.raid?
      raid == true
    end
  end
end

recorded = Module.new
recorded.module_eval("def self.log(*); end; def self.log_once(*); end")
%w(PROGRESS SIDES ROUTES STORY_NAMES WORLD_TYPES TITLE_JOINT PER_PLAYER STORY_UNTOLD ROUTE_PART).each do |name|
  constant = source[/^  #{name} = .*?(?=\n\r?\n)/m] or raise "world_overview.rbx has no #{name}"
  recorded.module_eval(constant)
end
%w(story_code story_text variable switch? world_story_code world_story_text title_tail difficulty_name).each do |name|
  method = source[/^  def self\.#{Regexp.escape(name)}(?=[\s(]).*?\n  end\r?\n/m] or raise "world_overview.rbx has no #{name}"
  recorded.module_eval(method)
end

$data_system = RecordedSystem.new

# Records a player's place in the story.
#
# @param progress [Integer] Variable 1001.
# @param routes [Hash] The routes' variables by the overview's route names.
# @param sides [Array<String>] The sides chosen.
# @return [Hash] The case.
def story_case(recorded, progress, routes, sides)
  $game_variables = Hash.new(0)
  $game_switches = {}
  $game_variables[1001] = progress
  { "destroyer" => 1141, "judgment" => 1142, "chaos" => 1143 }.each { |route, id| $game_variables[id] = routes[route].to_i }
  { "alice" => 4, "ilias" => 5 }.each { |side, id| $game_switches[id] = sides.include?(side) }
  request = { "p" => progress, "routes" => %w(chaos destroyer judgment).map { |route| [route, routes[route].to_i] }.to_h,
              "sides" => %w(ilias alice).map { |side| [side, sides.include?(side)] }.to_h }
  { "request" => request, "code" => recorded.story_code }
end

stories = [
  [0, {}, []], [18, {}, ["alice"]], [19, {}, ["alice"]], [33, {}, ["ilias"]], [34, {}, []], [45, {}, ["alice"]],
  [39, { "destroyer" => 3 }, ["alice"]], [45, { "judgment" => 1 }, []], [45, { "chaos" => 2 }, ["ilias"]],
  [45, { "chaos" => 1, "destroyer" => 1 }, []], [25, { "destroyer" => 1 }, ["alice"]], [45, {}, ["ilias", "alice"]],
].map { |progress, routes, sides| story_case(recorded, progress, routes, sides) }

texts = [nil, "", "1", "2:alice", "2:ilias", "3:destroyer", "3:judgment", "3:chaos", "3:other", "ad", "3:alice:extra"].map do |code|
  { "code" => code, "text" => recorded.story_text(code) }
end

worlds = [nil, "1", "2", "3", "ad", "mr", "chaos"].map do |part|
  routes = MGQ_MpWorldStory::ROUTES.index(part)
  MGQ_MpWorldStory.world = part.nil? ? nil : routes ? { "p" => 45, "r#{MGQ_MpWorldStory::ROUTE_VARIABLES[routes]}" => 1 } : { "p" => { "1" => 5, "2" => 25, "3" => 45 }[part] }
  { "part" => part, "code" => recorded.world_story_code, "text" => recorded.world_story_text }
end

titles = [[true, 1], [true, nil], [false, nil], [false, -2], [true, 4], [true, 99]].map do |raid, difficulty|
  MGQ_MpCoop::Scope.raid = raid
  MGQ_MpWorldDifficulty.value = difficulty
  # The World page's note, as world_overview_pages.rbx writes it.
  note = [recorded::WORLD_TYPES[raid], recorded.difficulty_name || recorded::PER_PLAYER].join(recorded::TITLE_JOINT)
  { "raid" => raid, "difficulty" => difficulty, "tail" => recorded.title_tail, "note" => note }
end

cases = { "stories" => stories, "texts" => texts, "worlds" => worlds, "titles" => titles }
File.write(File.join(__dir__, "story.json"), JSON.pretty_generate(cases) + "\n")
